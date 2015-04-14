from __future__ import division, absolute_import

import time

import numpy

from RO.Comm.TwistedTimer import Timer

from twistedActor import expandUserCmd, CommandQueue, LinkCommands

from .baseDev import BaseDevice

__all__ = ["ShutterDevice"]

class ShutterTimer(object):
    """Measure elapsed time.

    @todo Copied from galilDevice.  Probably should
    break this out somewhere (twisted Actor?)
    """
    def __init__(self):
        """Construct a ShutterTimer in the reset state
        """
        self.reset()

    def reset(self):
        """Reset (halt) timer; getTime will return nan until startTimer called
        """
        self.initTime = numpy.nan

    def startTimer(self):
        """Start the timer
        """
        self.initTime = time.time()

    def getTime(self):
        """Return elapsed time since last call to startTimer

        Return nan if startTimer not called since construction or last reset.
        """
        return "%.2f"%(self._getTime())

    def _getTime(self):
        return time.time() - self.initTime

class ShutterStatus(object):
    def __init__(self):
        self.isOpen = False
        self.shutterTimer = ShutterTimer()
        self.lastExpTime = -1
        self.lastDesExpTime = -1

class ShutterDevice(BaseDevice):
    def __init__(self, name, host, port, callFunc=None):
        """!Construct an ShutterDevice

        Inputs:
        @param[in] name  name of device
        @param[in] host  host address of Galil controller
        @param[in] port  port of Galil controller
        @param[in] callFunc  function to call when state of device changes;
                note that it is NOT called when the connection state changes;
                register a callback with "conn" for that task.
        """
        self.status = ShutterStatus()
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

    def open(self, userCmd=None):
        """!Open the shutter

        @param[in] position  an integer
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd(userCmd, "open")
        userCmd.addCallback(self._openCallback)
        return userCmd

    def _openCallback(self, userCmd):
        if userCmd.isDone and not userCmd.didFail:
            self.status.isOpen = True

    def close(self, userCmd=None):
        """!Close the shutter
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd(userCmd, "close")
        # when this command finishes set state to closed
        userCmd.addCallback(self._closeCallback)
        return userCmd

    def _closeCallback(self, userCmd):
        if userCmd.isDone and not userCmd.didFail:
            self.status.isOpen = False

    def expose(self, expTime, userCmd=None):
        """!Open the shutter for the desired amount of time, then close it, and get
        exposure time

        @param[in] expTime amount of time to open the shutter for (seconds, float)
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        openCmd = self.open()
        holdCmd = self.holdOpen(expTime)
        closeCmd = self.close()
        statusCmd = self.status()
        LinkCommands(userCmd, (openCmd, holdCmd, closeCmd, statusCmd))
        return userCmd

    def holdOpen(self, expTime):
        userCmd = expandUserCmd(None)
        def _holdOpen(userCmd):
            Timer(float(expTime), userCmd.setState, userCmd.Done)
            self.status.shutterTimer.startTimer()
            self.status.lastExpTime = -1
            self.status.lastDesExpTime = expTime
        self.cmdQueue.addCmd(userCmd, _holdOpen)
        return userCmd

    def parseStatusLine(self, statusLine):
        for keyVal in statusLine.split():
            if keyVal.startsWith("open="):
                self.status.isOpen = keyVal.split("open=")[-1] == "True"
            else:
                assert keyVal.startsWith("expTime=")
                self.status.lastExpTime = float(keyVal.split("expTime=")[-1])



