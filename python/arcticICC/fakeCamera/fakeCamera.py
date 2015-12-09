from __future__ import division, absolute_import

import time
from astropy.io import fits
import numpy

from RO.Comm.TwistedTimer import Timer

import arcticICC.camera as arctic

from arcticICC.camera import CameraConfig

# exp types
Bias = arctic.Bias
Dark = arctic.Dark
Flat = arctic.Flat
Object = arctic.Object

# image states
# Idle = "Idle"
# Exposing = "Exposing"
# Paused = "Paused"
# Reading = "Reading"
# ImageRead = "ImageRead"

Idle = arctic.Idle
Exposing = arctic.Exposing
Paused = arctic.Paused
Reading = arctic.Reading
ImageRead = arctic.ImageRead

# read rates
Slow = arctic.Slow
Medium = arctic.Medium
Fast = arctic.Fast

# read amps
LL = arctic.LL
LR = arctic.LR
UR = arctic.UR
UL = arctic.UL
Quad = arctic.Quad

readTime = 3 # seconds

CCDWidth = 4096
CCDHeight = 4096 # from 4096?
XOverscan = 102
MaxBinFactor = 4
XBinnedPrescanPerAmp = 2
YQuadBorder = 2

StateEnum = {
    "Idle" : 0,
    "Exposing" : 1,
    "Paused" : 2,
    "Reading" : 3,
    "ImageRead" : 4,
}

class Exposure(object):
    def __init__(self, expTime, expType, name):
        self.expTime = expTime
        self.expType = expType
        self.name = name

class ExposureState(object):
    def __init__(self, state, fullTime, remTime):
        self.state = state
        self.fullTime = fullTime
        self.remTime = remTime

    def isBusy(self):
        return self.state in [Exposing, Paused, Reading]

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
        self.setConfig(CameraConfig())
        self._expName = ""
        self.failExposure = False # for unittesting

    def isBusy(self):
        return self.state != Idle

    def startExposure(self, expTime, expType, name):
        if self.failExposure:
            raise RuntimeError("startExposure() failed!")
        assert expType in [Bias, Dark, Flat, Object]
        assert not self.isBusy()
        self.currExposure = Exposure(expTime, expType, name)
        self.expAccumulated = 0
        self._expName = name
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
        expTime = self.currExposure.expTime
        if self.state != Idle:
            timeRemaining = expTime - (time.time() - self.expBegin)
        else:
            timeRemaining = 0.
        return ExposureState(self.state, expTime or 0., timeRemaining)

    def getConfig(self):
        return self._config

    def setConfig(self, config):
        config.assertValid()
        self._assertIdle()
        self._config = config;

    def saveImage(self, expTime=-1):
        # save an empty file
        # fileName = "%s_%s_%s.fakeImage"%(self.currExposure.expType, self.currExposure.expTime, self.currExposure.name)
        # print "exptype", self.currExposure.expType
        # print "expTime", self.currExposure.expTime
        # print "expName", self.currExposure.name
        n = numpy.arange(100.0) # a simple sequence of floats from 0.0 to 99.9
        hdu = fits.PrimaryHDU(n)
        hdulist = fits.HDUList([hdu])
        hdulist[0].header["comment"] = "This is a fake image, used for testing."
        hdulist.writeto(self.currExposure.name)
        # open(self.currExposure.name, "w").close()
        self.state = Idle

    def openShutter(self):
        pass

    def closeShutter(self):
        pass

    def _setState(self, state):
        assert state in [Idle, Exposing, Paused, Reading, ImageRead]
        self.state = state

    def _startOrResumeExposure(self, expTime):
        self._setState(Exposing)
        self.expTimer.start(expTime, self._setState, Reading)
        self.readTimer.start(expTime+readTime, self._setState, ImageRead)
        self.expBegin = time.time()

    def _cancelTimers(self):
        self.readTimer.cancel()
        self.expTimer.cancel()

    def _assertIdle(self):
        if not self.state == Idle:
            raise RuntimeError("busy")




