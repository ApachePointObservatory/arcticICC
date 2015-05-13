from __future__ import division, absolute_import

import time

from RO.Comm.TwistedSocket import TCPServer
from RO.Comm.TwistedTimer import Timer
from twisted.python import failure

moveTime = 0.5 # seconds per filter
replyTimeDelay = 0.1 # delay before the ok is sent

__all__ = ["FakeFilterWheel", "FakeShutter"]

class FakeDev(TCPServer):
    """!A server that emulates an echoing device for testing
    """
    def __init__(self, name, port):
        """!Construct a fake device controller

        @param[in] name  name of device controller
        @param[in] port  port on which to command device controller
        """
        self.replyTimer = Timer()
        TCPServer.__init__(self,
            port=port,
            stateCallback=self.stateCallback,
            sockReadCallback = self.sockReadCallback,
            sockStateCallback = self.sockStateCallback,
        )

    def sockReadCallback(self, sock):
        cmdStr = sock.readLine()
        sock.writeLine(cmdStr)
        self.parseCmdStr(cmdStr)

    def parseCmdStr(self, cmdStr):
        raise NotImplementedError

    def sockStateCallback(self, sock):
        if sock.state == sock.Connected:
            print("Client at %s connected" % (sock.host))
        elif sock.state == sock.Closed:
            print("Client at %s disconnected" % (sock.host))
        if sock.isReady:
#             print "Set user=", sock
            self.userSock = sock
        else:
#             print "Delete user"
            self.userSock = None

    def sendOK(self):
        self.userSock.writeLine("OK")

class FakeFilterWheel(FakeDev):
    """!A server that emulates a filter wheel
    """
    MoveTime = 0.5 # seconds between filters
    def __init__(self, name, port):
        """!Construct a fake filter wheel controller

        @param[in] name  name of filter wheel controller
        @param[in] port  port on which to command filter wheel controller
        """
        self.isMoving = False
        self.position = 0

        FakeDev.__init__(self,
            name = name,
            port=port,
        )

    def parseCmdStr(self, cmdStr):
        if "status" in cmdStr.lower():
            self.sendStatusAndOK()
        elif "move" in cmdStr.lower():
            # get the new position
            newPos = int(cmdStr.split()[-1])
            dist = abs(self.position-newPos)
            time2move = dist*self.MoveTime
            self.isMoving = True
            self.position = newPos
            self.replyTimer.start(time2move, self.moveDone)
        elif "init" in cmdStr.lower():
            self.replyTimer.start(replyTimeDelay, self.sendOK)
        else:
            raise RuntimeError("Unknown Command: %s"%cmdStr)

    def sendStatusAndOK(self):
        statusStr = "moving=%s position=%i OK"%(str(self.isMoving), self.position)
        self.userSock.writeLine(statusStr)

    def moveDone(self):
        self.isMoving = False
        self.sendOK()

    def stateCallback(self, server=None):
        if self.isReady:
            # self.readyDeferred.callback(None)
            print("Fake filter wheel controller %s running on port %s" % (self.name, self.port))
        elif self.didFail and not self.readyDeferred.called:
            errMsg = "Fake filter wheel controller %s failed to start on port %s" % (self.name, self.port)
            print(errMsg)
            # self.readyDeferred.errback(failure.Failure(RuntimeError(errMsg)))


class FakeShutter(FakeDev):
    """!A server that emulates a shutter
    """
    def __init__(self, name, port):
        """!Construct a fake shutter controller

        @param[in] name  name of shutter controller
        @param[in] port  port on which to command shutter controller
        """
        self.isOpen = False
        self.expTime = -1

        FakeDev.__init__(self,
            name = name,
            port=port,
        )

    def parseCmdStr(self, cmdStr):
        if "status" in cmdStr.lower():
            self.sendStatusAndOK()
            return
        elif "open" in cmdStr:
            assert not self.isOpen
            self.expTime = time.time()
            self.isOpen = True
        elif "close" in cmdStr:
            assert self.isOpen
            self.expTime = time.time() - self.expTime
            self.isOpen = False
        elif "init" in cmdStr.lower():
            pass
        else:
            # unknown command?
            raise RuntimeError("Unknown Command: %s"%cmdStr)
        self.replyTimer.start(replyTimeDelay, self.sendOK)

    def sendStatusAndOK(self):
        statusStr = "open=%s expTime=%.4f OK"%(str(self.isOpen), self.expTime)
        self.userSock.writeLine(statusStr)

    def stateCallback(self, server=None):
        if self.isReady:
            # self.readyDeferred.callback(None)
            print("Fake shutter controller %s running on port %s" % (self.name, self.port))
        elif self.didFail and not self.readyDeferred.called:
            errMsg = "Fake shutter controller %s failed to start on port %s" % (self.name, self.port)
            print(errMsg)
            # self.readyDeferred.errback(failure.Failure(RuntimeError(errMsg)))

