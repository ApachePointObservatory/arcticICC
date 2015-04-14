from __future__ import division, absolute_import

from twistedActor import CommandQueue, expandUserCmd

from .baseDev import BaseDevice

__all__ = ["FilterWheelDevice"]

class FilterWheelStatus(object):
    def __init__(self):
        self.isMoving = False
        self.position = None

class FilterWheelDevice(BaseDevice):
    def __init__(self, name, host, port, callFunc=None):
        """!Construct an FilterWheelDevice

        Inputs:
        @param[in] name  name of device
        @param[in] host  host address of Galil controller
        @param[in] port  port of Galil controller
        @param[in] callFunc  function to call when state of device changes;
                note that it is NOT called when the connection state changes;
                register a callback with "conn" for that task.
        """
        self.status = FilterWheelStatus()
        BaseDevice.__init__(self,
            name = name,
            host = host,
            port = port,
            callFunc = callFunc,
            cmdInfo = (),
        )

        def setupCmdQueue(self):
            cmdQueue = CommandQueue(
                priorityDict = {
                    "init" : CommandQueue.Immediate,
                    # all other commands have an equal (default) priority
                }
            )
            return cmdQueue

    def move(self, position, userCmd=None):
        """!Move the filter wheel to the wanted position

        @param[in] position  an integer
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd(userCmd, "move %i"%position)
        return userCmd

    def parseStatusLine(self, statusLine):
        for keyVal in statusLine.split():
            if keyVal.startsWith("moving="):
                self.status.isMoving = keyVal.split("moving=")[-1] == "True"
            else:
                assert keyVal.startsWith("position=")
                self.status.position = int(keyVal.split("position=")[-1])