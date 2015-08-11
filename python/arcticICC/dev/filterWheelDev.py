from __future__ import division, absolute_import

import collections

import RO

from twistedActor import CommandQueue, expandUserCmd

from .baseDev import BaseDevice

__all__ = ["FilterWheelDevice"]

FilterEnumNameDict = collections.OrderedDict((
    (1, RO.StringUtil.quoteStr("SDSS u")),
    (2, RO.StringUtil.quoteStr("SDSS g")),
    (3, RO.StringUtil.quoteStr("SDSS r")),
    (4, RO.StringUtil.quoteStr("SDSS i")),
    (5, RO.StringUtil.quoteStr("SDSS z")),
))

class FilterWheelStatus(object):
    def __init__(self):
        self.isMoving = False
        self.position = -1

    def getStatusStr(self):
        filterNames = "filterNames=" + ", ".join(FilterEnumNameDict.values())
        filterID = "filterID=%i"%self.position
        filterName = "filterName=%s"%(FilterEnumNameDict[self.position])
        return "; ".join([filterNames, filterID, filterName])

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
        self.queueDevCmd("move %i"%position, userCmd)
        return userCmd

    def home(self, userCmd=None):
        """!Home the filter wheel

        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd("home", userCmd)
        return userCmd

    def talk(self, text, userCmd=None):
        """!Home the filter wheel

        @param[in] text a string to send to the device
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd(text, userCmd)
        userCmd.setState(userCmd.Done)
        return userCmd

    def parseStatusLine(self, statusLine):
        # print("%s parseStatusLine(%s)"%(self, statusLine))
        for keyVal in statusLine.split():
            if keyVal.startswith("moving="):
                self.status.isMoving = keyVal.split("moving=")[-1] == "True"
            else:
                assert keyVal.startswith("position=")
                self.status.position = int(keyVal.split("position=")[-1])
                # print("%s set postion to %i"%(self, int(keyVal.split("position=")[-1])))
