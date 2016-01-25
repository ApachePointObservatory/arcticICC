from __future__ import division, absolute_import

"""Should this actor implement a queue (such that, ie, no exposure may be taken if the filter wheel is moving)
or the filter wheel may not move while an exposure is in progress?  Probably.
"""

import os
import syslog
import collections
import datetime

from astropy.io import fits

from RO.Comm.TwistedTimer import Timer

from twistedActor import Actor, expandUserCmd, log, LinkCommands, UserCmd

from .arcticCommandSet import arcticCommandSet
from .version import __version__

import arcticICC.camera as arctic

from arcticICC.fakeCamera import Camera as FakeCamera

from twistedActor.parse import ParseError

UserPort = 35000

ImageDir = os.path.join(os.getenv("HOME"), "images")

Bias = "Bias"
Dark = "Dark"
Flat = "Flat"
Object = "Object"
LL = "LL"
LR = "LR"
UR = "UR"
UL = "UL"
Quad = "Quad"
Single = "Single"
Auto = "Auto"
Fast = "Fast"
Medium = "Medium"
Slow = "Slow"


ExpTypeDict = collections.OrderedDict((
    (Bias, arctic.Bias),
    (Dark, arctic.Dark),
    (Flat, arctic.Flat),
    (Object, arctic.Object),
))

ReadoutAmpsNameEnumDict = collections.OrderedDict((
    (LL, arctic.LL),
    (LR, arctic.LR),
    (UR, arctic.UR),
    (UL, arctic.UL),
    (Quad, arctic.Quad),
))
ReadoutAmpsEnumNameDict = collections.OrderedDict((enum, name) for (name, enum) in ReadoutAmpsNameEnumDict.iteritems())

ReadoutRateDict = {
    arctic.LL: {
        arctic.Fast: (1.98, 6.0), # (gain, readnoise)
        arctic.Medium: (1.99, 3.8),
        arctic.Slow: (1.43, 3.4),
    },
    arctic.LR: {
        arctic.Fast: (1.97, 6.4),
        arctic.Medium: (1.97, 4.3),
        arctic.Slow: (1.42, 3.7),
    },
    arctic.UL: {
        arctic.Fast: (2.01, 6.4),
        arctic.Medium: (2.03, 4.6),
        arctic.Slow: (1.43, 3.8),
    },
    arctic.UR: {
        arctic.Fast: (1.99, 6.5),
        arctic.Medium: (1.98, 4.4),
        arctic.Slow: (1.41, 3.7),
    }
}

class AmplifierData(object):
    def __init__(self, amp):
        """! Construct an AmplifierData Obj
        @param[in] amp: one of arctic.LL, arctic.LR, arctic.UR, arctic.UL or arctic.Quad
        """
        assert amp in ReadoutAmpsNameEnumDict.values(), "%s not in %s"%(amp, ReadoutAmpsNameEnumDict.values())
        self.amp = amp

    @property
    def isTopHalf(self):
        if self.amp in [arctic.UR, arctic.UL]:
            return True
        else:
            return False

    @property
    def isRightHalf(self):
        if self.amp in [arctic.UR, arctic.LR]:
            return True
        else:
            return False

    @property
    def xIndex(self):
        if self.isRightHalf:
            return 1
        else:
            return 0

    @property
    def yIndex(self):
        if self.isTopHalf:
            return 1
        else:
            return 0

    @property
    def xyName(self):
        return "%i%i"%(self.xIndex+1, self.yIndex+1)

    @property
    def letteredName(self):
        return ReadoutAmpsEnumNameDict[self.amp]

    def getGain(self, readRate):
        """! Return gain for this amp for a specified readRate

        @param[in] readRate one of arctic.Slow, arctic.Medium, arctic.Fast
        """
        return ReadoutRateDict[self.amp][readRate][0]

    def getReadNoise(self, readRate):
        """! Return readnoise for this amp for a specified readRate

        @param[in] readRate one of arctic.Slow, arctic.Medium, arctic.Fast
        """
        return ReadoutRateDict[self.amp][readRate][1]


AmpDataMap = collections.OrderedDict((
    (arctic.LL, AmplifierData(arctic.LL)),
    (arctic.UL, AmplifierData(arctic.UL)),
    (arctic.LR, AmplifierData(arctic.LR)),
    (arctic.UR, AmplifierData(arctic.UR)),
))

ReadoutRateNameEnumDict = collections.OrderedDict((
    (Slow, arctic.Slow),
    (Medium, arctic.Medium),
    (Fast, arctic.Fast),
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
    Quad  : 0.29,
    Single: 0.50,
}
rowMult = {
    Quad  : 0.00103,
    Single: 0.00407,
}
pixMult = {
    Quad: {
        Fast  : 0.0000001207,
        Medium : 0.0000008999,
        Slow  : 0.0000021599,
    },
    Single: {
        Fast  : 0.0000004820,
        Medium: 0.0000037180,
        Slow  : 0.0000087624,
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
        self.expStartTime = None
        self.expType = None
        self.expTime = None
        Actor.__init__(self,
            userPort = userPort,
            maxUsers = 1,
            devs = (filterWheelDev, shutterDev),
            name = name,
            version = __version__,
            doConnect = True,
            doDevNameCmds = False,
            doDebugMsgs = self.test,
            )

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
        # connect (if not connected) and initialize devices
        filterDevCmd = expandUserCmd(None)
        shutterDevCmd = expandUserCmd(None)
        subCmdList.append(filterDevCmd)
        subCmdList.append(shutterDevCmd)
        if not self.filterWheelDev.isConnected:
            self.filterWheelDev.connect(userCmd=filterDevCmd)
        else:
            self.filterWheelDev.init(userCmd=filterDevCmd)

        if not self.shutterDev.isConnected:
            self.shutterDev.connect(userCmd=shutterDevCmd)
        else:
            self.shutterDev.init(userCmd=shutterDevCmd)
        if getStatus:
            # get status only when the conn/initialization is done
            def getStatus(foo):
                if userCmd.isDone:
                    self.getStatus()
            userCmd.addCallback(getStatus)
        LinkCommands(mainCmd=userCmd, subCmdList=subCmdList)
        if not self.exposeCmd.isDone:
            self.exposeCmd.setState(self.exposeCmd.Failed, "currently running exposure killed via init")
            self.exposeCleanup()
        return userCmd

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

    def getReadTime(self):
        """Determine the read time for the current camera configuration
        """
        config = self.camera.getConfig()
        width = int(config.getBinnedWidth())
        height = int(config.getBinnedHeight())
        totalPix = width*height
        readRate = ReadoutRateEnumNameDict[config.readoutRate]
        readAmps = ReadoutAmpsEnumNameDict[config.readoutAmps]
        if readAmps != Quad:
            readAmps = Single
        return dcOff[readAmps] + rowMult[readAmps] * height + pixMult[readAmps][readRate] * totalPix

    # def setTemp(self, tempSetpoint):
    #     """Set the temperature setpoint
    #     @param[in] tempSetpoint: float, the desired temperature setpoint
    #     """
    #     self._tempSetpoint = float(tempSetpoint)


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
            # assert arg == "initialize"
            self.setCamera()
            userCmd.setState(userCmd.Done)
        return True

    def cmd_filter(self, userCmd):
        """! Implement the filter command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        subCmd = userCmd.parsedCommand.subCommand
        userCmd = expandUserCmd(userCmd)
        if subCmd.cmdName == "initialize":
            if not self.filterWheelDev.isConnected:
                self.filterWheelDev.connect(userCmd)
            else:
                self.filterWheelDev.init(userCmd)
        elif subCmd.cmdName == "connect":
            self.filterWheelDev.connect(userCmd)
        elif subCmd.cmdName == "disconnect":
            self.filterWheelDev.disconnect(userCmd)
        elif subCmd.cmdName == "status":
            self.filterWheelDev.startCmd("status", userCmd=userCmd)
        elif subCmd.cmdName == "home":
            self.filterWheelDev.startCmd("home", userCmd=userCmd)
        elif subCmd.cmdName == "talk":
            talkTxt = subCmd.parsedPositionalArgs[0]
            self.filterWheelDev.startCmd(talkTxt, userCmd=userCmd)
        else:
            userCmd.setState(userCmd.Failed, "unhandled sub command: %s. bug"%(subCmd.cmdName,))
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
            if subCmd.cmdName == "Bias":
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
            # explicilty write abort exposure state
            self.writeToUsers("i", "exposureState=aborted,0")
            self.exposeCleanup()
        self.writeToUsers("i", self.exposureStateKW, userCmd)
        userCmd.setState(userCmd.Done)
        return True

    def doExpose(self, userCmd, expType, expTime, basename=None, comment=None):
        """!Begin a camera exposure

        @param[in] userCmd: a twistedActor UserCmd instance
        @param[in] expType: string, one of object, flat, dark, bias
        @param[in] expTime: float, exposure time.
        """

        if not self.exposeCmd.isDone:
            userCmd.setState(userCmd.Failed, "cannot start new exposure, self.exposeCmd not done")
            return
        if self.pollTimer.isActive:
            userCmd.setState(userCmd.Failed, "cannot start new exposure, self.pollTimer is active - bug")
            return
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
        self.expStartTime = datetime.datetime.now()
        log.info("startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName))
        self.expName = expName
        self.comment = comment
        self.expType = expType
        self.expTime = expTime
        self.readingFlag = False
        try:
            self.camera.startExposure(expTime, expTypeEnum, expName)
            self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
            if expType in ["object", "flat"]:
                self.writeToUsers("i", "shutter=open") # fake shutter
            self.expNum += 1
            self.pollCamera()
        except RuntimeError as e:
            self.exposeCmd.setState(self.exposeCmd.Failed, str(e))
            # note, check what state the exposure kw is in after a runtime error here?
            self.exposeCleanup()

    def pollCamera(self):
        """Begin continuously polling the camera for exposure status, write the image when ready.
        """
        expState = self.camera.getExposureState()
        if expState.state == arctic.Reading and not self.readingFlag:
            self.readingFlag = True
            self.writeToUsers("i", "shutter=closed") # fake shutter
            # self.startReadTime = time.time()
            self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
        if expState.state == arctic.ImageRead:
            log.info("saving image: exposure %s"%self.expName)
            self.camera.saveImage() # saveImage sets camera exp state to idle
            # write headers
            self.writeHeaders()
            # clean up
            log.info("exposure %s complete"%self.expName)
            self.exposeCleanup()
        elif expState.state == arctic.Idle:
            log.warn("pollCamera() called but exposure state is idle.  Should be harmless, but why did it happen?")
            self.exposeCleanup()
        else:
            # if the camera is not idle continue polling
            self.pollTimer.start(0.05, self.pollCamera)

    def writeHeaders(self):
        config = self.camera.getConfig()
        # note comment header is written by hub, so we don't
        # do it here
        # http://astropy.readthedocs.org/en/latest/io/fits/
        with fits.open(self.expName, mode='update') as hdulist:
            prihdr = hdulist[0].header
            # timestamp
            prihdr["date-obs"] = self.expStartTime.isoformat(), "TAI time at the start of the exposure"
            # filter info
            try:
                filterPos = int(self.filterWheelDev.filterPos)
            except:
                filterPos = "unknown"
            prihdr["filpos"] = filterPos, "filter position"
            prihdr["filter"] = self.filterWheelDev.filterName, "filter name"
            # explicitly add in BINX BINY BEGX BEGY for WCS computation made by hub
            prihdr["begx"] = config.winStartCol + 1, "beginning column of CCD window"
            prihdr["begy"] = config.winStartRow + 1, "beginning row of CCD window"
            prihdr["binx"] = config.binFacCol, "column bin factor"
            prihdr["biny"] = config.binFacRow, "row bin factor"
            prihdr["ccdbin1"] = config.binFacCol, "column bin factor" #duplicate of binx
            prihdr["ccdbin2"] = config.binFacRow, "row bin factor" #duplicate of biny
            prihdr["imagetyp"] = self.expType, "exposure type"
            expTimeComment = "exposure time (sec)"
            if self.expTime > 0:
                expTimeComment = "estimated " + expTimeComment
            prihdr["exptime"] = self.expTime, expTimeComment
            prihdr["readamps"] = ReadoutAmpsEnumNameDict[config.readoutAmps], "readout amplifier(s)"
            prihdr["readrate"] = ReadoutRateEnumNameDict[config.readoutRate], "readout rate"

            # DATASEC and BIASSEC
            # for the bias region: use all overscan except the first two columns (closest to the data)
            # amp names are <x><y> e.g. 11, 12, 21, 22
            prescanWidth = 3 if config.binFacCol == 3 else 2
            prescanHeight = 1 if config.binFacRow == 3 else 0
            if config.readoutAmps == arctic.Quad:
                # all 4 amps are being read out
                ampDataList = AmpDataMap.values()
                ampXYList = " ".join([ampData.xyName for ampData in ampDataList])
                prihdr["amplist"] = (ampXYList, "amplifiers read <x><y> e.g. 12=LR")
                overscanWidth  = config.getBinnedWidth()  - ((2 * prescanWidth) + config.winWidth) # total, not per amp
                overscanHeight = config.getBinnedHeight() - ((2 * prescanHeight) + config.winHeight) # total, not per amp
                for ampData in ampDataList:
                    # CSEC is the section of the CCD covered by the data (unbinned)
                    csecWidth  = config.winWidth  * config.binFacCol / 2
                    csecHeight = config.winHeight * config.binFacRow / 2
                    csecStartCol = 1 + csecWidth if ampData.isRightHalf else 1
                    csecStartRow = 1 + csecHeight if ampData.isTopHalf else 1
                    csecEndCol = csecStartCol + csecWidth  - 1
                    csecEndRow = csecStartRow + csecHeight - 1
                    csecKey = "csec" + ampData.xyName
                    csecValue = "[%i:%i,%i:%i]"%(csecStartCol, csecEndCol, csecStartRow, csecEndRow)
                    prihdr[csecKey] = csecValue, "data section of CCD (unbinned)"

                    # DSEC is the section of the image that is data (binned)
                    dsecStartCol = 1 + prescanWidth
                    if ampData.isRightHalf:
                        dsecStartCol += (config.winWidth / 2) + overscanWidth
                    dsecStartRow = 1 + prescanHeight
                    if ampData.isTopHalf:
                        dsecStartRow += (config.winHeight / 2) + overscanHeight
                    dsecEndCol = dsecStartCol + config.winWidth  - 1
                    dsecEndRow = dsecStartRow + config.winHeight - 1
                    dsecKey = "dsec" + ampData.xyName
                    dsecValue = "[%i:%i,%i:%i]"%(dsecStartCol, dsecEndCol, dsecStartRow, dsecEndRow)
                    prihdr[dsecKey] = dsecValue, "data section of image (binned)"

                    biasWidth = (overscanWidth / 2) - 2 # "- 2" to skip first two columns of overscan
                    colBiasEnd = config.getBinnedWidth() / 2
                    if ampData.isRightHalf:
                        colBiasEnd += biasWidth
                    colBiasStart = 1 + colBiasEnd - biasWidth
                    bsecKey = "bsec" + ampData.xyName
                    bsecValue = "[%i:%i,%i:%i]"%(colBiasStart,colBiasEnd,dsecStartRow, dsecEndRow)
                    prihdr[bsecKey] = bsecValue, "bias section of image (binned)"
                    prihdr["gtgain"+ampData.xyName] = ampData.getGain(config.readoutRate), "predicted gain (e-/ADU)"
                    prihdr["gtron"+ampData.xyName] = ampData.getReadNoise(config.readoutRate), "predicted read noise (e-)"

            else:
                # single amplifier readout
                ampData = AmpDataMap[config.readoutAmps]
                prihdr["amplist"] = ampData.xyName, "amplifiers read <x><y> e.g. 12=LR"

                overscanWidth  = config.getBinnedWidth()  - (prescanWidth + config.winWidth)
                overscanHeight = config.getBinnedHeight() - (prescanHeight + config.winHeight)

                csecWidth  = config.winWidth  * config.binFacCol
                csecHeight = config.winHeight * config.binFacRow
                csecStartCol = 1 + (config.winStartCol * config.binFacCol)
                csecStartRow = 1 + (config.winStartRow * config.binFacRow)
                csecEndCol = csecStartCol + csecWidth  - 1
                csecEndRow = csecStartRow + csecHeight - 1
                csecKey = "csec" + ampData.xyName
                csecValue = "[%i:%i,%i:%i]"%(csecStartCol, csecEndCol, csecStartRow, csecEndRow)
                prihdr[csecKey] = csecValue, "data section of CCD (unbinned)" #?

                dsecStartCol = 1 + config.winStartCol + prescanWidth
                dsecStartRow = 1 + config.winStartRow + prescanHeight
                dsecEndCol = dsecStartCol + config.winWidth  - 1
                dsecEndRow = dsecStartRow + config.winHeight - 1
                dsecKey = "dsec" + ampData.xyName
                dsecValue = "[%i:%i,%i:%i]"%(dsecStartCol, dsecEndCol, dsecStartRow, dsecEndRow)
                prihdr[dsecKey] = dsecValue, "data section of image (binned)"

                biasWidth = overscanWidth - 2 # "- 2" to skip first two columns of overscan
                colBiasEnd = config.getBinnedWidth()
                colBiasStart = 1 + colBiasEnd - biasWidth
                bsecKey = "bsec" + ampData.xyName
                bsecValue = "[%i:%i,%i:%i]"%(colBiasStart, colBiasEnd, dsecStartRow, dsecEndRow)
                prihdr[bsecKey] = bsecValue, "bias section of image (binned)"
                prihdr["gtgain"+ampData.xyName] = ampData.getGain(config.readoutRate), "predicted gain (e-/ADU)"
                prihdr["gtron"+ampData.xyName] = ampData.getReadNoise(config.readoutRate), "predicted read noise (e-)"


    def exposeCleanup(self):
        self.pollTimer.cancel() # just in case
        self.writeToUsers("i", self.exposureStateKW, self.exposeCmd)
        self.writeToUsers("i", "shutter=closed") # fake shutter
        if not self.exposeCmd.isDone:
            self.exposeCmd.setState(self.exposeCmd.Done)
        self.expName = None
        self.comment = None
        self.expStartTime = None
        self.expType = None
        self.expTime = None
        self.readingFlag = False

    def maxCoord(self, binFac=(1,1)):
        """Returns the maximum binned CCD coordinate, given a bin factor.
        """
        assert len(binFac) == 2, "binFac must have 2 elements; binFac = %r" % binFac
        # The value is even for both amplifiers, even if only using single readout,
        # just to keep the system more predictable. The result is that the full image size
        # is the same for 3x3 binning regardless of whether you read one amp or four,
        # and as a result you lose one row and one column when you read one amp.
        return [(4096, 4096)[ind] // int(2 * binFac[ind]) * 2 for ind in range(2)]

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

    def getCurrentBinnedCCDWindow(self, config):
        wind0 = config.winStartCol + 1
        wind1 = config.winStartRow + 1
        # wind2 = config.winWidth + wind0
        # wind3 = config.winHeight + wind1
        wind2 = config.winWidth + config.winStartCol
        wind3 = config.winHeight + config.winStartRow
        return [wind0, wind1, wind2, wind3]

    def getUnbinnedCCDWindow(self, config):
        window = self.getCurrentBinnedCCDWindow(config)
        return self.unbin(window, [config.binFacCol, config.binFacRow])

    def getBinnedCCDWindow(self, config, newBin=None):
        """Return a binned CCD window.  If newBin specified return window with
        new bin factor, otherwise use the current bin factor.
        """
        if newBin is None:
            return self.getCurrentBinnedCCDWindow(config)
        else:
            # determine new window size from new bin factor
            unbinnedWindow = self.getUnbinnedCCDWindow(config)
            print("max coord", self.maxCoord(binFac=newBin))
            return self.bin(unbinnedWindow, newBin)

    def setCCDWindow(self, config, window):
        """Window is a set of 4 integers, or a list of 1 element: ["full"]
        """
        if str(window[0]).lower() == "full":
            config.setFullWindow()
        else:
            try:
                window = [int(x) for x in window]
                assert len(window)==4
                # explicitly handle the off by 1 issue with 3x3 binning
                # note this is also handled in self.getBinnedCCDWindow
                # if now window was passed via the command string
                # if config.binFacCol == 3:
                #     window[2] = window[2] - 1
                # if config.binFacRow == 3:
                #     window[3] = window[3] - 1
                print("windowExplicit", window)
            except:
                raise ParseError("window must be 'full' or a list of 4 integers")
            config.winStartCol = window[0]-1 # leach is 0 indexed
            config.winStartRow = window[1]-1
            config.winWidth = window[2] - config.winStartCol # window width includes start and end row!
            config.winHeight = window[3] - config.winStartRow

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
            newColBin = ccdBin[0]
            newRowBin = newColBin if len(ccdBin) == 1 else ccdBin[1]
            if window is None:
                # calculate the new window with the new bin factors
                window = self.getBinnedCCDWindow(config, newBin=[newColBin, newRowBin])
            # set new bin factors
            config.binFacCol = newColBin
            config.binFacRow = newRowBin
        # windowing and amps need some careful handling...
        if window is not None:
            self.setCCDWindow(config, window)
            # if amps were not specified be sure this window works
            # with the current amp configuration, else yell
            # force the amps check
            if amps is None:
                amps = [ReadoutAmpsEnumNameDict[config.readoutAmps]]
        if amps is not None:
            # quad amp only valid for full window
            amps = amps[0]
            isFullWindow = config.isFullWindow()
            if not isFullWindow and amps==Quad:
                raise ParseError("amps=quad may only be specified with a full window")
            if isFullWindow and amps==Auto:
                config.readoutAmps = ReadoutAmpsNameEnumDict[Quad]
            elif not isFullWindow and amps==Auto:
                config.readoutAmps = ReadoutAmpsNameEnumDict[LL]
            else:
                config.readoutAmps = ReadoutAmpsNameEnumDict[amps]

        # set camera configuration if a configuration change was requested
        if True in [x is not None for x in [readoutRate, ccdBin, window, amps]]:
            # camera config was changed set it and output new camera status
            self.camera.setConfig(config)
            self.getStatus(doCamera=True, doFilter=False, doShutter=False)

        if temp is not None:
            self.setTemp(argDict["temp"][0])
        # move wants an int, maybe some translation should happend here
        # or some mapping between integers and filter names
        if filterPos is not None:
            # only set command done if move finishes successfully
            def setDoneAfterMove(mvCmd):
                if mvCmd.isDone:
                    # did the move fail? if so fail the userCmd and ask for status
                    if mvCmd.didFail:
                        userCmd.setState(userCmd.Failed, "Filter move failed: %s"%mvCmd.textMsg)
                    else:
                        userCmd.setState(userCmd.Done)
            pos = int(filterPos[0])
            # output commanded position keywords here (move to filterWheelActor eventually?)
            self.filterWheelDev.startCmd("move %i"%(pos,), callFunc=setDoneAfterMove) # userCmd set done in callback after status
        else:
            # done: output the new configuration
            userCmd.setState(userCmd.Done)
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
        # ccdWindow = (
        #     config.winStartCol + 1, # add one to adhere to tui's convention
        #     config.winStartRow + 1,
        #     config.winStartCol + config.winWidth,
        #     config.winStartRow + config.winHeight,
        # )
        ccdWindow = tuple(self.getBinnedCCDWindow(config))
        ccdUBWindow = tuple(self.unbin(ccdWindow, ccdBin))

        keyVals.append("ccdWindow=%i,%i,%i,%i"%(ccdWindow))
        keyVals.append("ccdUBWindow=%i,%i,%i,%i"%(ccdUBWindow))
        keyVals.append("isFullWindow=%s"%str(config.isFullWindow()))
        keyVals.append("ccdOverscan=%i,0"%arctic.XOverscan)
        # temerature stuff, where to get it?
        # keyVals.append("ampNames=%s"%(",".join([key.upper() for key in ReadoutAmpsNameEnumDict])))
        # only show Quad, and LL in TUI rather than all options
        keyVals.append("ampNames=%s, %s"%(LL, Quad))
        keyVals.append("ampName="+ReadoutAmpsEnumNameDict[config.readoutAmps])
        keyVals.append("readoutRateNames="+", ".join([x for x in ReadoutRateEnumNameDict.values()]))
        keyVals.append("readoutRateName=%s"%ReadoutRateEnumNameDict[config.readoutRate])
        # add these when they become available?
        # keyVals.append("ccdTemp=?")
        # if self.tempSetpoint is None:
        #     ts = "None"
        # else:
        #     ts = "%.2f"%self.tempSetpoint
        # keyVals.append("tempSetpoint=%s"%ts)
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








