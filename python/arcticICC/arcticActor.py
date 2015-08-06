from __future__ import division, absolute_import

"""Should this actor implement a queue (such that, ie, no exposure may be taken if the filter wheel is moving)
or the filter wheel may not move while an exposure is in progress?  Probably.
"""

import os
import syslog
import collections

from astropy.io import fits

from RO.Comm.TwistedTimer import Timer

from twistedActor import Actor, expandUserCmd, log, LinkCommands, UserCmd

# from .camera as arcticCamera

from .cmd import arcticCommandSet
from .version import __version__

if os.environ.get("FAKECAMERA"):
    import arcticICC.fakeCamera as arctic
else:
    import arcticICC.camera as arctic
from arcticICC.cmd.parse import ParseError

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


class ArcticActor(Actor):
    Facility = syslog.LOG_LOCAL1
    # UserPort = 2200
    DefaultTimeLim = 5 # default time limit, in seconds
    def __init__(self,
        filterWheelDev,
        shutterDev,
        name="arcticICC",
        userPort = 2200,
    ):
        """!Construct an ArcticActor

        @param[in] camera instance
        @param[in] filterDev  a FilterWheelDevice instance
        @param[in] shutterDev  a ShutterDevice instance
        @param[in] name  actor name; used for logging
        """
        self.imageDir = ImageDir
        self.camera = arctic.Camera()
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

    @property
    def tempSetpoint(self):
        return self._tempSetpoint

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
        self.camera = None
        self.camera = arctic.Camera()
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
        log.info("%s.parseAndDispatchCmd cmdBody=%r"%cmd.cmdBody)
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
            self.camera = None
            self.camera = arctic.Camera()
            userCmd.setState(userCmd.Done)
        return True

    def cmd_filter(self, userCmd):
        """! Implement the filter command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        subCmd = userCmd.parsedCommand.subCommand
        if subCmd.cmdName == "status":
            self.getStatus(userCmd=userCmd, doCamera=False, doFilter=True, doShutter=False)
        elif subCmd.cmdName == "init":
            self.filterWheelDev.init(userCmd=userCmd)
        elif subCmd.cmdName == "home":
            self.filterWheelDev.home(userCmd=userCmd)
        else:
            assert subCmd.cmdName == "talk"
            talkTxt = subCmd.parsedPositionalArgs[0]
            self.filterWheelDev.talk(text=talkTxt, userCmd=userCmd)
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
        userCmd.setState(userCmd.Done)
        return True

    def doExpose(self, userCmd, expType, expTime, basename=None, comment=None):
        """!Begin a camera exposure

        @param[in] userCmd: a twistedActor UserCmd instance
        @param[in] expType: string, one of object, flat, dark, bias
        @param[in] expTime: float, exposure time.
        """
        # exceptions thrown from c++ code
        # expState = self.camera.getExposureState()
        # if expState != arctic.Idle:
        #     userCmd.setState(userCmd.failed, "Cannot start new exposure, camera exposure state is %s"%StatusStrDict[expState])
        #     return
        assert self.exposeCmd.isDone, "cannot start new exposure, self.exposeCmd not done"
        assert not self.pollTimer.isActive, "cannot start new exposure, self.pollTimer is active"
        self.exposeCmd = userCmd
        expTypeEnum = ExpTypeDict.get(expType)
        expName = os.path.abspath("%s_%d.fits" % (expType, self.expNum))
        expName = "%s_%d.fits" % (expType, self.expNum)
        if basename:
            expName = basename + "_" + expName
        if not os.path.exists(self.imageDir):
            os.makedirs(self.imageDir)
        expName = os.path.join(self.imageDir, expName)
        print "startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName)
        log.info("startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName))
        self.expName = expName
        self.comment = comment
        self.camera.startExposure(expTime, expTypeEnum, expName)
        self.expNum += 1
        self.pollCamera()

    def pollCamera(self):
        """Begin continuously polling the camera for exposure status, write the image when ready.
        """
        expState = self.camera.getExposureState()
        # statusStr = "%s %0.1f %0.1f" % (StatusStrDict.get(expState.state), expState.fullTime, expState.remTime)
        # print(statusStr)
        # self.writeToUsers("i", statusStr, self.exposeCmd)
        # log.info(statusStr)
        if expState.state == arctic.ImageRead:
            print("saving image: exposure %s"%self.expName)
            log.info("saving image: exposure %s"%self.expName)
            self.camera.saveImage() # saveImage sets camera exp state to idle
        if expState.state != arctic.Idle:
            # if the camera is not idle continue polling
            self.pollTimer.start(0., self.pollCamera)
        else:
            # camera is idle, clean up
            print("exposure %s complete"%self.expName)
            log.info("exposure %s complete"%self.expName)
            # was a comment associated with this exposure
            if self.comment:
                print("adding comment %s to exposure %s"%(self.comment, self.expName))
                self.writeComment()
            self.exposeCmd.setState(self.exposeCmd.Done)
            self.expName = None
            self.comment = None

    def writeComment(self):
        # http://astropy.readthedocs.org/en/latest/io/fits/
        hdulist = fits.open(self.expName, mode='update')
        prihdr = hdulist[0].header
        prihdr['comment'] = self.comment
        hdulist.close()

    def cmd_set(self, userCmd):
        """! Implement the set command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        argDict = userCmd.parsedCommand.parsedFloatingArgs
        # check validity first
        amps = argDict["amps"][0]
        window = argDict["window"]
        if window[0] != "full":
            try:
                [int(x) for x in window]
                assert len(window)==4
            except:
                raise ParseError("window must be 'full' or a list of 4 integers")
        if amps == "quad" and window[0] != "full":
            raise ParseError("amps=quad may only be specified with window='full'")
        if amps == "auto":
            if window[0] != "full":
                amps = "ll"
            else:
                amps = "quad"

        # begin replacing config values
        config = self.camera.getConfig()
        config.readoutRate = ReadoutRateNameEnumDict[argDict["readoutRate"][0]]
        # binning
        colBin = argDict["bin"][0]
        config.binFacCol = colBin
        rowBin = colBin if len(argDict["bin"]) == 1 else argDict["bin"][1]
        config.binFacRow = rowBin
        # window
        if argDict["window"][0] == "full":
            config.setFullWindow()
        else:
            config.winStartCol = int(argDict["window"][0])
            config.winStartRow = int(argDict["window"][1])
            config.winWidth = int(argDict["window"][2])
            config.winHeight = int(argDict["window"][3])
        config.readoutAmps = ReadoutAmpsNameEnumDict[amps]
        self.camera.setConfig(config)

        self.setTemp(argDict["temp"][0])
        # move wants an int, maybe some translation should happend here
        # or some mapping between integers and filter names
        pos = int(argDict["filter"][0])
        self.filterWheelDev.move(pos, userCmd) # fiterWheel will set command done
        return True

    def cmd_status(self, userCmd):
        """! Implement the status command
        @param[in]  userCmd  a twistedActor command with a parsedCommand attribute
        """
        statusStr = self.getCameraStatus()
        self.writeToUsers("i", statusStr, cmd=userCmd)
        self.getStatus(userCmd)
        return True

    def getCameraStatus(self):
        """! Return a formatted string of current camera
        status
        """
        config = self.camera.getConfig()
        keyVals = []
        # camera state
        keyVals.append("busy=%s"%self.camera.isBusy())
        # bin
        keyVals.append("bin=[%i,%i]"%(config.binFacCol, config.binFacRow))
        # window
        keyVals.append("window=[%i,%i,%i,%i]"%(config.winStartCol, config.winStartRow, config.winWidth, config.winHeight))
        # temerature stuff, where to get it?
        keyVals.append("readoutAmps=%s"%ReadoutAmpsEnumNameDict[config.readoutAmps])
        keyVals.append("readoutRate=%s"%ReadoutRateEnumNameDict[config.readoutRate])
        keyVals.append("temp=?")
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
        if doCamera:
            statusStr = self.getCameraStatus()
            self.writeToUsers("i", statusStr, cmd=userCmd)
        devList = []
        if doFilter:
            devList.append(self.filterWheelDev)
        if doShutter:
            devList.append(self.shutterDev)
        userCmd = expandUserCmd(userCmd)
        subCmdList = []
        for dev in devList:
            subCmdList.append(dev.getStatus())
        LinkCommands(userCmd, subCmdList)
        return userCmd








