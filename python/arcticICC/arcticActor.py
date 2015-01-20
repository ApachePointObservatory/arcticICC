from __future__ import division, absolute_import

import syslog

from twistedActor import BaseActor
from .cmd import arcticCommandSet
from .version import __version__

class ArcticActor(BaseActor):
    Facility = syslog.LOG_LOCAL1
    UserPort = 2200
    def __init__(self,
        name="arcticICC",
    ):
        """Construct an ArcticActor
        @param[in] name  actor name; used for logging
        @param[in] userPort  port on which to listen for users
        """
        BaseActor.__init__(self, userPort=self.UserPort, maxUsers=1, name=name, version=__version__)

    def parseAndDispatchCmd(self, cmd):
        """Dispatch the user command

        @param[in] cmd  user command (a twistedActor.UserCmd)
        """
        parsedCommand = arcticCommandSet.parse(cmd.cmdBody)
        print("command: ", parsedCommand.cmdName)
        if parsedCommand.subCommand:
            print("subCommand: ", parsedCommand.subCommand.cmdName)
            parsedCommand = parsedCommand.subCommand
        print("Floating Args: ")
        for arg, val in parsedCommand.parsedFloatingArgs.iteritems():
            print("Float Arg: ", arg, ": ", val)
        for arg in parsedCommand.parsedPositionalArgs:
            print("Pos Arg: ", arg)