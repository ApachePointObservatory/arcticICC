from __future__ import division, absolute_import

import syslog

from twistedActor import Actor, expandUserCmd, log, LinkCommands

from .fakeCamera import fakeCamera as arctic

from .cmd import arcticCommandSet
from .version import __version__

class CameraStatus(object):
    pass

class ArcticActor(Actor):
    Facility = syslog.LOG_LOCAL1
    UserPort = 2200
    DefaultTimeLim = 5 # default time limit, in seconds
    def __init__(self,
        filterWheelDev,
        shutterDev,
        name="arcticICC",
    ):
        """!Construct an ArcticActor

        @param[in] filterDev  a FilterWheelDevice instance
        @param[in] shutterDev  a ShutterDevice instance
        @param[in] name  actor name; used for logging
        """
        self.camera = arctic.Camera()
        self.filterWheelDev = filterWheelDev
        self.shutterDev = shutterDev
        # BaseActor.__init__(self, userPort=self.UserPort, maxUsers=1, name=name, version=__version__)
        Actor.__init__(self,
            userPort = self.UserPort,
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
        if getStatus:
            # put a status on the queue after the init. Use StatusInitVerb
            # to run the status at high priority, so it cannot be interrupted by a MOVE
            # of similar command, which would make the returned userCmd fail
            devCmd0 = self.startCmd("INIT", timeLim=timeLim)
            devCmd1 = self.startCmd("STATUS", timeLim=timeLim, devCmdVerb=self.StatusInitVerb)
            LinkCommands(mainCmd=userCmd, subCmdList=[devCmd0, devCmd1])
        else:
            self.startCmd("INIT", userCmd=userCmd, timeLim=timeLim)
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
        userCmd.setState(userCmd.Done)
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
        print str(userCmd.cmdID)
        userCmd.setState(userCmd.Done)
        return True

