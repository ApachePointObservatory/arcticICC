from __future__ import division, absolute_import

import syslog

from twistedActor import Actor, expandUserCmd, log, LinkCommands

# from .camera as arcticCamera

from .cmd import arcticCommandSet
from .version import __version__


class CameraStatus(object):
    # Bias = "Bias"
    # Dark = "Dark"
    # Flat = "Flat"
    # Object = "Object"

    # ExpTypes = (Bias, Dark, Flat, Object)

    # LL = "LL"
    # LR = "LR"
    # UR = "UR"
    # UL = "UL"
    # Quad = "Quad"

    # ReadoutAmpsNames = (LL, LR, UR, UL, Quad)

    # Slow = "Slow"
    # Medium = "Medium"
    # Fast = "Fast"

    # ReadoutRateNames = (Slow, Medium, Fast)

    # Idle = "Idle"
    # Exposing = "Exposing"
    # Paused = "Paused"
    # Reading = "Reading"
    # ImageRead = "ImageRead"

    # StatusStrs = (Idle, Exposing, Paused, Reading, ImageRead)

    def __init__(self, camera):
        self.camera = camera
        # self.expStatus = None
        # self.expType = None
        # self.readoutAmps = None
        # self.readoutRate = None
        # self.binFactor = (None, None)
        # self.window = (None, None, None, None) # startCol, startRow, width, height
        # self.temp = None
        # self.tempSetpoint = None





class ArcticActor(Actor):
    Facility = syslog.LOG_LOCAL1
    # UserPort = 2200
    DefaultTimeLim = 5 # default time limit, in seconds
    def __init__(self,
        camera,
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
        self.camera = camera
        self.cameraStatus = CameraStatus(camera)
        self.filterWheelDev = filterWheelDev
        self.shutterDev = shutterDev
        # BaseActor.__init__(self, userPort=self.UserPort, maxUsers=1, name=name, version=__version__)
        Actor.__init__(self,
            userPort = userPort,
            maxUsers = 1,
            devs = (filterWheelDev, shutterDev),
            name = name,
            version = __version__,
            doConnect = True,
            doDevNameCmds = False,
            )

    def init(self, userCmd=None, getStatus=True, timeLim=DefaultTimeLim):
        """! Initialize all devices, and get status if wanted
        @param[in]  userCmd  a UserCmd or None
        @param[in]  getStatus if true, query all devices for status
        @param[in]  timeLim
        """
        userCmd = expandUserCmd(userCmd)
        log.info("%s.init(userCmd=%s, timeLim=%s, getStatus=%s)" % (self, userCmd, timeLim, getStatus))
        subCmdList = []
        for dev in [self.filterWheelDev, self.shutterDev]:
            subCmdList.append(dev.init())
        if getStatus:
            subCmdList.append(self.getStatus())
        LinkCommands(mainCmd=userCmd, subCmdList=subCmdList)
        return userCmd

    def parseAndDispatchCmd(self, cmd):
        """Dispatch the user command

        @param[in] cmd  user command (a twistedActor.UserCmd)
        """
        parsedCommand = arcticCommandSet.parse(cmd.cmdBody)

        # append the parsedCommand to the cmd object, and send along
        cmd.parsedCommand = parsedCommand
        return Actor.parseAndDispatchCmd(self, cmd)

        # route the parsed command to the correct cmd_ method
        # cmdFunc = self.locCmdDict.get(parsedCommand.cmdName)
        # if cmdFunc is not None:
        #     # execute local command
        #     try:
        #         self.checkLocalCmd(cmd)
        #         retVal = cmdFunc(cmd, parsedCommand)
        #     except CommandError as e:
        #         cmd.setState("failed", strFromException(e))
        #         return
        #     except Exception as e:
        #         sys.stderr.write("command %r failed\n" % (cmd.cmdStr,))
        #         sys.stderr.write("function %s raised %s\n" % (cmdFunc, strFromException(e)))
        #         traceback.print_exc(file=sys.stderr)
        #         quotedErr = quoteStr(strFromException(e))
        #         msgStr = "Exception=%s; Text=%s" % (e.__class__.__name__, quotedErr)
        #         self.writeToUsers("f", msgStr, cmd=cmd)
        #     else:
        #         if not retVal and not cmd.isDone:
        #             cmd.setState("done")
        #     return
        # print("command: ", parsedCommand.cmdName)
        # if parsedCommand.subCommand:
        #     print("subCommand: ", parsedCommand.subCommand.cmdName)
        #     parsedCommand = parsedCommand.subCommand
        # print("Floating Args: ")
        # for arg, val in parsedCommand.parsedFloatingArgs.iteritems():
        #     print("Float Arg: ", arg, ": ", val)
        # for arg in parsedCommand.parsedPositionalArgs:
        #     print("Pos Arg: ", arg)
        # cmd.setState(cmd.Done)
        # self.writeToOneUser("f", "UnknownCommand=%s" % (cmd.cmdVerb,), cmd=cmd)


    def cmd_camera(self, userCmd):
        print "got camera"
        userCmd.setState(userCmd.Done)
        return True

    def cmd_filter(self, userCmd):
        print "got filter"
        userCmd.setState(userCmd.Done)
        return True

    def cmd_init(self, userCmd):
        print "got init"
        self.init(userCmd, getStatus=True)
        # userCmd.setState(userCmd.Done)
        return True

    def cmd_expose(self, userCmd):
        print "got expose"
        userCmd.setState(userCmd.Done)
        return True

    def cmd_set(self, userCmd):
        print "got set"
        userCmd.setState(userCmd.Done)
        return True

    def cmd_status(self, userCmd):
        print "got status"
        self.getStatus(userCmd)
        return True

    def getCameraStatus(self, userCmd=None):
        pass


    def getStatus(self, userCmd=None):
        userCmd = expandUserCmd(userCmd)
        subCmdList = []
        for dev in [self.filterWheelDev, self.shutterDev]:
            subCmdList.append(dev.getStatus())
        LinkCommands(userCmd, subCmdList)
        return userCmd








