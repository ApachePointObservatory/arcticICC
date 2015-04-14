from __future__ import division, absolute_import

import time

from RO.Comm.TwistedTimer import Timer

# exp types
Bias = "Bias"
Dark = "Dark"
Flat = "Flat"
Object = "Object"

# image states
Idle = "Idle"
Exposing = "Exposing"
Paused = "Paused"
Reading = "Reading"
ImageRead = "ImageRead"

# read rates
Slow = "Slow"
Medium = "Medium"
Fast = "Fast"

# read amps
LL = "LL"
LR = "LR"
UR = "UR"
UL = "UL"
Quad = "Quad"

readTime = 3 # seconds

class Exposure(object):
    def __init__(self, expTime, expType, name):
        self.expTime = expTime
        self.expType = expType
        self.name = name

class Camera(object):

    def __init__(self):
        """A pure python fake camera
        """
        self.state = Idle
        self.currExposure = Exposure(None, None, None)
        self.expTimer = Timer()
        self.readTimer = Timer()
        self.expBegin = None
        self.expAccumulated = None

    def isBusy(self):
        return self.state != Idle

    def startExposure(self, expTime, expType, name):
        assert expType in [Bias, Dark, Flat, Object]
        assert not self.isBusy()
        self.currExposure = Exposure(expTime, expType, name)
        self.expAccumulated = 0
        self._startOrResumeExposure(expTime)

    def pauseExposure(self):
        assert self.state == Exposing
        self.expAccumulated = self.expAccumulated + time.time() - self.expBegin
        self._cancelTimers()
        self._setState(Paused)

    def resumeExposure(self):
        assert self.state == self.Paused
        remExpTime = self.currExposure.expTime - self.expAccumulated
        self._startOrResumeExposure(remExpTime)

    def abortExposure(self):
        assert self.state == Exposing
        self._cancelTimers()
        self._setState(Idle)

    def stopExposure(self):
        assert self.state == Exposing
        self._cancelTimers()
        self._setState(ImageRead)

    def getExposureState(self):
        return self.state

    def getConfig(self, configObj):
        pass

    def setConfig(self, configObj):
        pass

    def saveImage(self, expTime):
        # save an empty file
        fileName = "%s_%s_%s.fakeImage"%(self.currExposure.expType, self.currExposure.expTime, self.currExposure.name)
        open(fileName, "w").close()

    def openShutter(self):
        pass

    def closeShutter(self):
        pass

    def _setState(self, state):
        assert state in [Idle, Exposing, Paused, Reading, ImageRead]
        self.state = state

    def _startOrResumeExposure(self, expTime):
        self._setState(Exposing)
        self.expTimer(expTime, self._setState, Reading)
        self.readTimer(expTime+readTime, self._setState, ImageRead)
        self.expBegin = time.time()

    def _cancelTimers(self):
        self.readTimer.cancel()
        self.expTimer.cancel()



