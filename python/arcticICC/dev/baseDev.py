from __future__ import division, absolute_import

import time

import numpy

from RO.StringUtil import strFromException

from twistedActor import TCPDevice, expandUserCmd, log

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

class BaseDevice(TCPDevice):
    def __init__(self, name, host, port, callFunc=None):
        """!Construct an BaseDevice

        Inputs:
        @param[in] name  name of device
        @param[in] host  host address of Galil controller
        @param[in] port  port of Galil controller
        @param[in] callFunc  function to call when state of device changes;
                note that it is NOT called when the connection state changes;
                register a callback with "conn" for that task.
        """
        self.cmdQueue = self.setupCmdQueue()
        self.currDevCmdStr = "" # last string sent to the device
        self.waitingForInitEcho = False
        TCPDevice.__init__(self,
            name = name,
            host = host,
            port = port,
            callFunc = callFunc,
            cmdInfo = (),
        )

    @property
    def currExeCmd(self):
        return self.cmdQueue.currExeCmd.cmd

    def setupCmdQueue(self):
        """! Must return a CommandQueue,
        init should be of priority immediate
        """
        raise NotImplementedError

    def init(self, userCmd=None, timeLim=None, getStatus=None):
        """!Initialize the shutter
        @param[in] userCmd  a twistedActor.BaseCommand
        @param[in] timeLim  time limit for the init
        @param[in] getStatus required argument for init
        """
        userCmd = expandUserCmd(userCmd)
        if not hasattr(userCmd, "cmdVerb"):
            userCmd.cmdVerb = "init"
        if timeLim is not None:
            userCmd.setTimeLimit(timeLim)
        self.queueDevCmd("init", userCmd)
        return userCmd

    def _statusCallback(self, cmd):
        """! When status command is complete, send info to users
        """
        if cmd.isDone:
            self.writeToUsers("i", self.status.getStatusStr(), cmd)

    def getStatus(self, userCmd=None):
        """!Query the device for status
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd("status", userCmd)
        userCmd.addCallback(self._statusCallback)
        return userCmd

    def handleReply(self, replyStr):
        """Handle a line of output from the device. Called whenever the device outputs a new line of data.

        @param[in] replyStr   the reply, minus any terminating \n

        Tasks include:
        - Parse the reply
        - Manage the pending commands
        - Output data to users
        - Parse status to update the model parameters
        - If a command has finished, call the appropriate command callback
        """
        log.info("%s read %r, currExeCmd: %r" % (self, replyStr, self.currExeCmd))
        # print("%s read %r, currExeCmd: %r, currDevCmdStr: %s" % (self, replyStr, self.currExeCmd, self.currDevCmdStr))
        if self.currExeCmd.isDone:
            log.info("Ignoring unsolicited output from Galil: %s " % replyStr)
            return
        gotOK = False
        if replyStr == "OK":
            replyStr = ""
            gotOK = True
        elif replyStr.endswith(" OK"):
            gotOK = True
            replyStr = replyStr[:-3]
        # handle things specially for init
        if self.waitingForInitEcho:
            if replyStr != "init":
                return
            else:
                # saw init echo
                self.waitingForInitEcho = False
                replyStr = ""
        if replyStr and replyStr != self.currDevCmdStr:
            # must be status parse and set accordingly
            self.parseStatusLine(replyStr)
        if gotOK:
            self.currExeCmd.setState(self.currExeCmd.Done)

    def parseStatusLine(self, statusLine):
        """! Parse a line of status, set things accordingly
        """
        raise NotImplementedError

    def queueDevCmd(self, devCmdStr, userCmd):
        def queueFunc(userCmd):
            self.startDevCmd(devCmdStr)
        self.cmdQueue.addCmd(userCmd, queueFunc)
        log.info("%s.runCommand(userCmd=%r, devCmdStr=%r, cmdQueue: %r"%(self, userCmd, devCmdStr, self.cmdQueue))

    def startDevCmd(self, devCmdStr):
        """
        @param[in] devCmdStr a line of text to send to the device
        """
        log.info("%s.startDevCmd(%r)" % (self, devCmdStr))
        try:
            if self.conn.isConnected:
                log.info("%s writing %r" % (self, devCmdStr))
                self.conn.writeLine(devCmdStr)
                if devCmdStr == "init":
                    self.waitingForInitEcho = True
                self.currDevCmdStr = devCmdStr
            else:
                self.currExeCmd.setState(self.currExeCmd.Failed, "Not connected")
        except Exception as e:
            self.currExeCmd.setState(self.currExeCmd.Failed, textMsg=strFromException(e))



