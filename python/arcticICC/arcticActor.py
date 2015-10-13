from __future__ import division, absolute_import

"""Should this actor implement a queue (such that, ie, no exposure may be taken if the filter wheel is moving)
or the filter wheel may not move while an exposure is in progress?  Probably.
"""

import os
import syslog
import collections
import time

from astropy.io import fits

from RO.Comm.TwistedTimer import Timer

from twistedActor import Actor, expandUserCmd, log, LinkCommands, UserCmd

from .cmd import arcticCommandSet
from .version import __version__

import arcticICC.camera as arctic

from arcticICC.fakeCamera import Camera as FakeCamera

from arcticICC.cmd.parse import ParseError

UserPort = 35000

ImageDir = os.path.join(os.getenv("HOME"), "images")

ExpTypeDict = collections.OrderedDict((
    ("bias", arctic.Bias),
    ("dark", arctic.Dark),
    ("flat", arctic.Flat),
    ("object", arctic.Object),
))

ReadoutAmpsNameEnumDict = collections.OrderedDict((
    ("ll", arctic.LL),
    ("lr", arctic.LR),
    ("ur", arctic.UR),
    ("ul", arctic.UL),
    ("quad", arctic.Quad),
))
ReadoutAmpsEnumNameDict = collections.OrderedDict((enum, name) for (name, enum) in ReadoutAmpsNameEnumDict.iteritems())

ReadoutRateNameEnumDict = collections.OrderedDict((
    ("slow", arctic.Slow),
    ("medium", arctic.Medium),
    ("fast", arctic.Fast),
))
ReadoutRateEnumNameDict = collections.OrderedDict((enum, name) for (name, enum) in ReadoutRateNameEnumDict.iteritems())

StatusStrDict = {
    arctic.Idle:      "Idle",
    arctic.Exposing:  "Exposing",
    arctic.Paused:    "Paused",
    arctic.Reading:   "Reading",
    arctic.ImageRead: "ImageRead",
}

# exposureState=string
# The state of any running exposure. Runs through the following:
# flushing - the CCDs are being flushed.
# integrating - an object or dark exposure is integrating (resuming a paused exposure generates integrating)
# reading - the CCDs are being read out.
# paused - an object exposure has been paused. Resuming will generate integrating
# done - the exposure has been successfully finished.
# aborted - the exposure has been aborted, and the image discarded.

"""
Empirically modeled read time estimates
Model is:
readtime = dcOff + rowCoeff * nRows + pixCoeff * nRows * nCols
dcOff, rowCoeff, pixCoeff were solved using a least squares solver
readtimes were measured for a number of binning / windowing / read rate combiniations
for Quad and ll readout modes
here are the full solutions
fastQuad:        dcOff=0.2652573793  rowMult=0.0010169505  pixMult=0.0000001207
medQuad:         dcOff=0.2898826491  rowMult=0.0010118056  pixMult=0.0000008999
slowQuad:        dcOff=0.2891650735  rowMult=0.0010299422  pixMult=0.0000021599
fastLL:          dcOff=0.5022872975  rowMult=0.0040308398  pixMult=0.0000004820
medLL:           dcOff=0.4625591256  rowMult=0.0040650412  pixMult=0.0000037180
slowLL:          dcOff=0.4715621773  rowMult=0.0040715685  pixMult=0.0000087624
"""

# use the largest values so we tend to err on slight over estimation (nicer for the user)
dcOff = {
    "quad"  : 0.29,
    "single": 0.50,
}
rowMult = {
    "quad"  : 0.00103,
    "single": 0.00407,
}
pixMult = {
    "quad": {
        "fast"  : 0.0000001207,
        "medium": 0.0000008999,
        "slow"  : 0.0000021599,
    },
    "single": {
        "fast"  : 0.0000004820,
        "medium": 0.0000037180,
        "slow"  : 0.0000087624,
    }
}


class ArcticActor(Actor):
    Facility = syslog.LOG_LOCAL1
    DefaultTimeLim = 5 # default time limit, in seconds
    def __init__(self,
        filterWheelDev,
        shutterDev,
        name="arcticICC",
        userPort = UserPort,
        test=False,
    ):
        """!Construct an ArcticActor

        @param[in] filterWheelDev  a FilterWheelDevice instance
        @param[in] shutterDev  a ShutterDevice instance
        @param[in] name  actor name; used for logging
        @param[in] userPort port on which this service runs
        @param[in] test bool. If true, use a fake camera.
        """
        self.imageDir = ImageDir
        self.test = test
        self.setCamera()
        self.filterWheelDev = filterWheelDev
        self.shutterDev = shutterDev
        self._tempSetpoint = None
        self.expNum = 0
        self.exposeCmd = UserCmd()
        self.exposeCmd.setState(UserCmd.Done)
        self.pollTimer = Timer()
        self.expName = None
        self.comment = None
        Actor.__init__(self,
            userPort = userPort,
            maxUsers = 1,
            devs = (filterWheelDev, shutterDev),
            name = name,
            version = __version__,
            doConnect = True,
            doDevNameCmds = False,
            )

    def setCamera(self):
        self.camera = None
        if self.test:
            # use fake camera
            self.camera = FakeCamera()
        else:
            self.camera = arctic.Camera()

    @property
    def tempSetpoint(self):
        return self._tempSetpoint

    @property
    def exposureStateKW(self):
        arcticExpState = self.camera.getExposureState()
        arcticStatusInt = arcticExpState.state
        #translate from arctic status string to output that hub/tui expect
        if arcticStatusInt == arctic.Idle:
            expStateStr = "done"
        elif arcticStatusInt == arctic.Exposing:
            expStateStr = "integrating"
        elif arcticStatusInt == arctic.Paused:
            expStateStr = "paused"
        elif arcticStatusInt in [arctic.Reading, arctic.ImageRead]:
            expStateStr = "reading"
        if arcticStatusInt == arctic.Reading:
            # use modeled exposure time
            fullTime = self.getReadTime()
        else:
            fullTime = arcticExpState.fullTime
        return "exposureState=%s, %.4f"%(expStateStr, fullTime)

        # timeStampNow = datetime.datetime.now().strftime("%Y-%M-%dT%H:%M:%S.%f")
        # return "exposureState=%s,%s,%.4f,%.4f"%(expStateStr, timeStampNow, arcticExpState.fullTime, arcticExpState.remTime)

    def getReadTime(self):
        """Determine the read time for the current camera configuration
        """
        config = self.camera.getConfig()
        width = int(config.getBinnedWidth())
        height = int(config.getBinnedHeight())
        totalPix = width*height
        readRate = ReadoutRateEnumNameDict[config.readoutRate]
        readAmps = ReadoutAmpsEnumNameDict[config.readoutAmps]
        if readAmps != "quad":
            readAmps = "single"
        return dcOff[readAmps] + rowMult[readAmps] * height + pixMult[readAmps][readRate] * totalPix

    def setTemp(self, tempSetpoint):
        """Set the temperature setpoint
        @param[in] tempSetpoint: float, the desired temperature setpoint
        """
        self._tempSetpoint = float(tempSetpoint)

    def init(self, userCmd=None, getStatus=True, timeLim=DefaultTimeLim):
        """! Initialize all devices, and get status if wanted
        @param[in]  userCmd  a UserCmd or None
        @param[in]  getStatus if true, query all devices for status
        @param[in]  timeLim
        """
        userCmd = expandUserCmd(userCmd)
        log.info("%s.init(userCmd=%s, timeLim=%s, getStatus=%s)" % (self, userCmd, timeLim, getStatus))
        # initialize camera
        self.setCamera()
        subCmdList = []
        # initialize devices
        for dev in [self.filterWheelDev, self.shutterDev]:
            subCmdList.append(dev.init())
        if getStatus:
            subCmdList.append(self.getStatus())
        LinkCommands(mainCmd=userCmd, subCmdList=subCmdList)
        return userCmd

    def parseAndDispatchCmd(self, cmd):
        """Dispatch the user command, parse the cmd string and append the result as a parsedCommand attribute
        on cmd

        @param[in] cmd  user command (a twistedActor.UserCmd)
        """
        log.info("%s.parseAndDispatchCmd cmdBody=%r"%(self, cmd.cmdBody))
        if not cmd.cmdBody:
            # echo to show alive
            self.writeToOneUser(":", "", cmd=cmd)
            return

        parsedCommand = arcticCommandSet.parse(cmd.cmdBody)

        # append the parsedCommand to the cmd object, and send along
        cmd.parsedCommand = parsedCommand
        return Actor.parseAndDispatchCmd(self, cmd)

    def cmd_camera(self, userCmd):
        """! Implement the camera command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        arg = userCmd.parsedCommand.parsedPositionalArgs[0]
        if arg == "status":
            self.getStatus(userCmd=userCmd, doCamera=True, doFilter=False, doShutter=False)
        else:
            # how to init the camera, just rebuild it?
            assert arg == "init"
            self.setCamera()
            userCmd.setState(userCmd.Done)
        return True

    def cmd_filter(self, userCmd):
        """! Implement the filter command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        subCmd = userCmd.parsedCommand.subCommand
        userCmd = expandUserCmd(userCmd)
        # if subCmd.cmdName == "status":
        #     self.getStatus(userCmd=userCmd, doCamera=False, doFilter=True, doShutter=False)
        # elif subCmd.cmdName == "init":
        #     self.filterWheelDev.init(userCmd=userCmd)
        # elif subCmd.cmdName == "home":
        #     self.filterWheelDev.home(userCmd=userCmd)
        # else:
        #     assert subCmd.cmdName == "talk"
        if subCmd.cmdName == "talk":
            talkTxt = subCmd.parsedPositionalArgs[0]
            self.filterWheelDev.startCmd(talkTxt, userCmd=userCmd)
        else:
            # just pass along the command
            assert subCmd.cmdName in ["status", "init", "home"]
            self.filterWheelDev.startCmd(subCmd.cmdName, userCmd=userCmd)
        return True

    def cmd_init(self, userCmd):
        """! Implement the init command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        self.init(userCmd, getStatus=True)
        # userCmd.setState(userCmd.Done)
        return True

    def cmd_ping(self, userCmd):
        """! Implement the ping command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        userCmd.setState(userCmd.Done, textMsg="alive")
        return True

    def cmd_expose(self, userCmd):
        """! Implement the expose command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        subCmd = userCmd.parsedCommand.subCommand
        if subCmd.cmdName not in ["pause", "resume", "stop", "abort"]:
            # no current exposure, start one
            basename = subCmd.parsedFloatingArgs.get("basename", [None])[0]
            comment = subCmd.parsedFloatingArgs.get("comment", [None])[0]
            if subCmd.cmdName == "bias":
                expTime = 0
            else:
                expTime = subCmd.parsedFloatingArgs["time"][0]
            self.doExpose(userCmd, expType=subCmd.cmdName, expTime=expTime, basename=basename, comment=comment)
            return True
        # there is a current exposure
        if subCmd.cmdName == "pause":
            self.camera.pauseExposure()
        elif subCmd.cmdName == "resume":
            self.camera.resumeExposure()
        elif subCmd.cmdName == "stop":
            self.camera.stopExposure()
        else:
            assert subCmd.cmdName == "abort"
            self.camera.abortExposure()
        self.writeToUsers("i", self.exposureStateKW, userCmd)
        userCmd.setState(userCmd.Done)
        return True

    def doExpose(self, userCmd, expType, expTime, basename=None, comment=None):
        """!Begin a camera exposure

        @param[in] userCmd: a twistedActor UserCmd instance
        @param[in] expType: string, one of object, flat, dark, bias
        @param[in] expTime: float, exposure time.
        """
        assert self.exposeCmd.isDone, "cannot start new exposure, self.exposeCmd not done"
        assert not self.pollTimer.isActive, "cannot start new exposure, self.pollTimer is active"
        self.exposeCmd = userCmd
        expTypeEnum = ExpTypeDict.get(expType)
        if basename:
            # save location was specified
            expName = basename
        else:
            # wasn't specified choose a default place/name
            if not os.path.exists(self.imageDir):
                os.makedirs(self.imageDir)
            expName = os.path.abspath("%s_%d.fits" % (expType, self.expNum))
            expName = "%s_%d.fits" % (expType, self.expNum)
            expName = os.path.join(self.imageDir, expName)
        # print "startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName)
        self.expStartTime = time.time()
        log.info("startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName))
        self.expName = expName
        self.comment = comment
        self.readingFlag = False
        self.camera.startExposure(expTime, expTypeEnum, expName)
        self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
        self.expNum += 1
        self.pollCamera()

    def pollCamera(self):
        """Begin continuously polling the camera for exposure status, write the image when ready.
        """
        expState = self.camera.getExposureState()
        if expState.state == arctic.Reading and not self.readingFlag:
            self.readingFlag = True
            # self.startReadTime = time.time()
            self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
        if expState.state == arctic.ImageRead:
            log.info("saving image: exposure %s"%self.expName)
            self.camera.saveImage() # saveImage sets camera exp state to idle
            # clean up
            log.info("exposure %s complete"%self.expName)
            #was a comment associated with this exposure
            # comment is actually written by the hub!
            # if self.comment:
            #     print("adding comment %s to exposure %s"%(self.comment, self.expName))
            #     self.writeComment()
            self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
            self.exposeCmd.setState(self.exposeCmd.Done)
            self.expName = None
            self.comment = None
            self.readingFlag = False
        elif expState.state != arctic.Idle:
            # if the camera is not idle continue polling
            self.pollTimer.start(0.05, self.pollCamera)

    def writeComment(self):
        # http://astropy.readthedocs.org/en/latest/io/fits/
        hdulist = fits.open(self.expName, mode='update')
        prihdr = hdulist[0].header
        prihdr['comment'] = self.comment
        hdulist.close()

    def maxCoord(self, binFac=(1,1)):
        """Returns the maximum binned CCD coordinate, given a bin factor.
        """
        assert len(binFac) == 2, "binFac must have 2 elements; binFac = %r" % binFac
        return [(4096, 4096)[ind] // int(binFac[ind]) for ind in range(2)]

    def minCoord(self, binFac=(1,1)):
        """Returns the minimum binned CCD coordinate, given a bin factor.
        """
        assert len(binFac) == 2, "binFac must have 2 elements; binFac = %r" % binFac
        return (1, 1)

    def unbin(self, binnedCoords, binFac):
        """Copied from TUI

        Converts binned to unbinned coordinates.

        The output is constrained to be in range (but such constraint is only
        needed if the input was out of range).

        A binned coordinate can be be converted to multiple unbinned choices (if binFac > 1).
        The first two coords are converted to the smallest choice,
        the second two (if supplied) are converted to the largest choice.
        Thus 4 coordinates are treated as a window with LL, UR coordinates, inclusive.

        Inputs:
        - binnedCoords: 2 or 4 coords; see note above

        If any element of binnedCoords or binFac is None, all returned elements are None.
        """
        assert len(binnedCoords) in (2, 4), "binnedCoords must have 2 or 4 elements; binnedCoords = %r" % binnedCoords
        if len(binFac) == 1:
            binFac = binFac*2
        assert len(binFac) == 2, "binFac must have 2 elements; binFac = %r" % binFac

        if None in binnedCoords or None in binFac:
            return (None,)*len(binnedCoords)

        binXYXY = binFac * 2
        subadd = (1, 1, 0, 0)

        # compute value ignoring limits
        unbinnedCoords = [((binnedCoords[ind] - subadd[ind]) * binXYXY[ind]) + subadd[ind]
            for ind in range(len(binnedCoords))]

        # apply limits
        minUnbinXYXY = self.minCoord()*2
        maxUnbinXYXY = self.maxCoord()*2
        unbinnedCoords = [min(max(unbinnedCoords[ind], minUnbinXYXY[ind]), maxUnbinXYXY[ind])
            for ind in range(len(unbinnedCoords))]
        return unbinnedCoords

    def bin(self, unbinnedCoords, binFac):
        """Copied from TUI

        Converts unbinned to binned coordinates.

        The output is constrained to be in range for the given bin factor
        (if a dimension does not divide evenly by the bin factor
        then some valid unbinned coords are out of range when binned).

        Inputs:
        - unbinnedCoords: 2 or 4 coords

        If any element of binnedCoords or binFac is None, all returned elements are None.
        """
        assert len(unbinnedCoords) in (2, 4), "unbinnedCoords must have 2 or 4 elements; unbinnedCoords = %r" % unbinnedCoords
        if len(binFac) == 1:
            binFac = binFac*2
        assert len(binFac) == 2, "binFac must have 2 elements; binFac = %r" % binFac

        if None in unbinnedCoords or None in binFac:
            return (None,)*len(unbinnedCoords)

        binXYXY = binFac * 2

        # compute value ignoring limits
        binnedCoords = [1 + ((unbinnedCoords[ind] - 1) // int(binXYXY[ind]))
            for ind in range(len(unbinnedCoords))]

        # apply limits
        minBinXYXY = self.minCoord(binFac)*2
        maxBinXYXY = self.maxCoord(binFac)*2
        binnedCoords = [min(max(binnedCoords[ind], minBinXYXY[ind]), maxBinXYXY[ind])
            for ind in range(len(binnedCoords))]
        return binnedCoords

    def cmd_set(self, userCmd):
        """! Implement the set command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        argDict = userCmd.parsedCommand.parsedFloatingArgs
        if not argDict:
            # nothing was passed?
            raise ParseError("no arguments received for set command")
        ccdBin = argDict.get("bin", None)
        amps = argDict.get("amps", None)
        window = argDict.get("window", None)
        readoutRate = argDict.get("readoutRate", None)
        temp = argDict.get("temp", None)
        filterPos = argDict.get("filter", None)
        # begin replacing/and checking config values
        config = self.camera.getConfig()

        if readoutRate is not None:
            config.readoutRate = ReadoutRateNameEnumDict[readoutRate[0]]
        if ccdBin is not None:
            prevCCDBin = [config.binFacCol, config.binFacRow]
            colBin = ccdBin[0]
            config.binFacCol = colBin
            rowBin = colBin if len(ccdBin) == 1 else ccdBin[1]
            config.binFacRow = rowBin
            if window is None:
                # adjust window based on new bin (if the window wasn't explicitly passed)
                # adjust previous window for new bin factor
                prevCoords = [
                    config.winStartCol + 1,
                    config.winStartRow + 1,
                    config.winWidth + config.winStartCol,
                    config.winHeight + config.winStartRow,
                ]
                unbinnedCoords = self.unbin(prevCoords, prevCCDBin)
                window = self.bin(unbinnedCoords, ccdBin)
        # windowing and amps need some careful handling...
        if window is not None:
            if str(window[0]) == "full":
                config.setFullWindow()
            else:
                try:
                    window = [int(x) for x in window]
                    assert len(window)==4
                except:
                    raise ParseError("window must be 'full' or a list of 4 integers")
                config.winStartCol = window[0]-1 # leach is 0 indexed
                config.winStartRow = window[1]-1
                config.winWidth = window[2] - config.winStartCol
                config.winHeight = window[3] - config.winStartRow
            # if amps were not specified be sure this window works
            # with the current amp configuration, else yell
            # force the amps check
            if amps is None:
                amps = [ReadoutAmpsEnumNameDict[config.readoutAmps]]
        if amps is not None:
            # quad amp only valid for full window
            isFullWindow = config.isFullWindow()
            if not isFullWindow and amps[0]=="quad":
                raise ParseError("amps=quad may only be specified with a full window")
            if isFullWindow and amps[0]=="auto":
                config.readoutAmps = ReadoutAmpsNameEnumDict["quad"]
            elif not isFullWindow and amps[0]=="auto":
                config.readoutAmps = ReadoutAmpsNameEnumDict["ll"]
            else:
                config.readoutAmps = ReadoutAmpsNameEnumDict[amps[0]]

        # set camera configuration
        self.camera.setConfig(config)

        if temp is not None:
            self.setTemp(argDict["temp"][0])
        # move wants an int, maybe some translation should happend here
        # or some mapping between integers and filter names
        if filterPos is not None:
            def getStatusAfterMove(mvCmd):
                if mvCmd.isDone:
                    self.getStatus(userCmd) # set the userCmd done
            pos = int(filterPos[0])
            self.filterWheelDev.startCmd("move %i"%(pos,), callFunc=getStatusAfterMove) # userCmd set done in callback after status
        else:
            # done: output the new configuration
            self.getStatus(userCmd) # get status will set command done
        return True

    def cmd_status(self, userCmd):
        """! Implement the status command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        # statusStr = self.getCameraStatus()
        # self.writeToUsers("i", statusStr, cmd=userCmd)
        self.getStatus(userCmd)
        return True

    def getCameraStatus(self):
        """! Return a formatted string of current camera
        status
        """
        config = self.camera.getConfig()
        keyVals = []
        # exposure state
        keyVals.append(self.exposureStateKW)
        keyVals.append("ccdState=ok") # a potential lie?
        keyVals.append("ccdSize=%i,%i"%(arctic.CCDWidth, arctic.CCDHeight))

        # bin
        ccdBin = (config.binFacCol, config.binFacRow)
        keyVals.append("ccdBin=%i,%i"%(ccdBin))
        # window
        keyVals.append("shutter=%s"%("open" if self.camera.getExposureState().state == arctic.Exposing else "closed"))
        ccdWindow = (
            config.winStartCol + 1, # add one to adhere to tui's convention
            config.winStartRow + 1,
            config.winStartCol + config.winWidth,
            config.winStartRow + config.winHeight,
        )
        ccdUBWindow = tuple(self.unbin(ccdWindow, ccdBin))

        keyVals.append("ccdWindow=%i,%i,%i,%i"%(ccdWindow))
        keyVals.append("ccdUBWindow=%i,%i,%i,%i"%(ccdUBWindow))
        keyVals.append("ccdOverscan=%i,0"%arctic.XOverscan)
        # temerature stuff, where to get it?
        keyVals.append("ampNames=ll,quad")
        keyVals.append("ampName="+ReadoutAmpsEnumNameDict[config.readoutAmps])
        keyVals.append("readoutRateNames="+", ".join([x for x in ReadoutRateEnumNameDict.values()]))
        keyVals.append("readoutRateName=%s"%ReadoutRateEnumNameDict[config.readoutRate])
        keyVals.append("ccdTemp=?")
        if self.tempSetpoint is None:
            ts = "None"
        else:
            ts = "%.2f"%self.tempSetpoint
        keyVals.append("tempSetpoint=%s"%ts)
        return "; ".join(keyVals)

    def getStatus(self, userCmd=None, doCamera=True, doFilter=True, doShutter=True):
        """! A generic status command, arguments specify which statuses are wanted
        @param[in] userCmd a twistedActor UserCmd or none
        @param[in] doCamera: bool, if true get camera status
        @param[in] doFilter: bool, if true get filter wheel status
        @param[in] doShutter: bool, if true get shutter status
        """
        assert True in [doFilter, doShutter, doCamera]
        userCmd = expandUserCmd(userCmd)
        if doCamera:
            statusStr = self.getCameraStatus()
            self.writeToUsers("i", statusStr, cmd=userCmd)
        subCmdList = []
        if doShutter:
            subCmdList.append(self.shutterDev.getStatus())
        if doFilter:
            subCmdList.append(self.filterWheelDev.startCmd("status"))
        if subCmdList:
            LinkCommands(userCmd, subCmdList)
        else:
            userCmd.setState(userCmd.Done)
        return userCmd








