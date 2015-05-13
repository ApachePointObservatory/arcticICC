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

CCDWidth = 4096
CCDHeight = 4096 # from 4096?
XOverscan = 102
MaxBinFactor = 4
XBinnedPrescanPerAmp = 2
YQuadBorder = 2

class CameraConfig(object):

        def __init__(self):
            self.readoutAmps = Quad # default to quad
            self.readoutRate = Medium # default to fast
            self.binFacCol = 2 # default to 1x1 binning
            self.binFacRow = 2
            self.winStartCol = 0
            self.winStartRow = 0
            self.winWidth = CCDWidth/2
            self.winHeight = CCDHeight/2
            self.setFullWindow()

        def assertValid(self):
            return #
            if (not self.isFullWindow() and not self.canWindow()):
                errMsg = "cannot window unless reading from a single amplifier; readoutAmps="
                    #+ ReadoutAmpsNameMap.find(readoutAmps)->second
                raise RuntimeError(errMsg)

            if (self.binFacCol < 1 or self.binFacCol > MaxBinFactor):
                errMsg = "binFacCol=" + str(self.binFacCol) + " < 1 or > " + str(MaxBinFactor)
                raise RuntimeError(errMsg)

            if (self.binFacRow < 1 or self.binFacRow > MaxBinFactor):
                errMsg = "binFacRow=" + str(self.binFacRow) + " < 1 or > " + str(MaxBinFactor)
                raise RuntimeError(errMsg)


            binnedCCDWidth = self.computeBinnedWidth(CCDWidth)
            binnedCCDHeight = self.computeBinnedHeight(CCDHeight)
            if ((self.winStartCol < 0) or (self.winStartCol >= binnedCCDWidth)):
                errMsg = "winStartCol=" + str(self.winStartCol) + " < 0 or >= " + str(binnedCCDWidth)
                raise RuntimeError(errMsg)

            if ((self.winStartRow < 0) or (self.winStartRow >= binnedCCDHeight)):
                errMsg = "winStartRow=" + str(self.winStartRow) + " < 0 or >= " + str(binnedCCDHeight)
                raise RuntimeError(errMsg)

            if ((self.winWidth < 1) or (self.winWidth > binnedCCDWidth - self.winStartCol)):
                errMsg = "winWidth=" + str(self.winWidth) + " < 1 or > " + str(binnedCCDWidth - self.winStartCol)
                raise RuntimeError(errMsg)

            if ((self.winHeight < 1) or (self.winHeight > binnedCCDHeight - self.winStartRow)):
                errMsg = "winHeight=" + str(self.winHeight) + " < 1 or > " + str(binnedCCDHeight - self.winStartRow)
                raise RuntimeError(errMsg)

            # if the following test fails we have mis-set some parameter or are mis-computing getBinnedWidth or getBinnedHeight
            if (self.getNumAmps() > 1):
                # the number of binned rows and columns must be even
                if ((self.getBinnedWidth() % 2 != 0) or (self.getBinnedHeight() % 2 != 0)):
                    errMsg = "Bug: reading from multiple amplifiers, so the binned width=" + str(self.getBinnedWidth()) + " and height=" + str(self.getBinnedHeight()) + " must both be even"
                    raise RuntimeError(errMsg)

        def canWindow(self):
            return self.getNumAmps == 1

        def getNumAmps(self):
            if self.readoutAmps == Quad:
                return 4
            else:
                return 1

        def setFullWindow(self):
            self.winStartCol = 0
            self.winStartRow = 0
            self.winWidth = self.computeBinnedWidth(CCDWidth)
            self.winHeight = self.computeBinnedHeight(CCDHeight)

        def getUnbinnedWidth(self):
            return self.getBinnedWidth() * self.binFacCol

        def getUnbinnedHeight(self):
            return self.getBinnedHeight() * self.binFacRow

        def getBinnedWidth(self):
            # Warning: if you change this code, also update getMaxWidth
            if self.getNumAmps() > 1:
                xPrescan = XBinnedPrescanPerAmp * 2
            else:
                xPrescan = XBinnedPrescanPerAmp * 1
            return self.winWidth + xPrescan + self.computeBinnedWidth(XOverscan)

        def getBinnedHeight(self):
            # Warning: if you change this code, also update getMaxHeight
            if self.getNumAmps() > 1:
                return self.winHeight + YQuadBorder
            else:
                return self.winHeight

        def isFullWindow(self):
            return (self.winStartRow == 0) and (self.winStartCol == 0) and (self.winWidth >= self.computeBinnedWidth(CCDWidth)) and (self.winHeight >= self.computeBinnedHeight(CCDHeight))

        def getMaxWidth(self):
            return CCDWidth + (2 * XBinnedPrescanPerAmp) + XOverscan

        def getMaxHeight(self):
            return CCDHeight + YQuadBorder

        def computeBinnedWidth(self, unbWidth):
            return ((unbWidth) / (2 * self.binFacCol)) * 2

        def computeBinnedHeight(self, unbHeight):
            return ((unbHeight) / (2 * self.binFacRow)) * 2

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
        self.setConfig(CameraConfig())

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

    def getConfig(self):
        return self._config

    def setConfig(self, config):
        config.assertValid()
        self._assertIdle()

        # runCommand("set col bin factor",  TIM_ID, WRM, ( Y_MEM | 0x5 ), config.binFacCol);

        # runCommand("set row bin factor",  TIM_ID, WRM, ( Y_MEM | 0x6 ), config.binFacRow);

        # if (config.isFullWindow()) {
        #     runCommand("set full window", TIM_ID, SSS, 0, 0, 0);
        # } else {
        #     # set subarray size; warning: this only works when reading from one amplifier
        #     # arguments are:
        #     # - arg1 is the bias region width (in pixels)
        #     # - arg2 is the subarray width (in pixels)
        #     # - arg3 is the subarray height (in pixels)
        #     int const xExtraPix = config.getBinnedWidth() - config.winWidth;
        #     runCommand("set window size", TIM_ID, SSS, xExtraPix, config.winWidth, config.winHeight);

        #     # set subarray starting-point; warning: this only works when reading from one amplifier
        #     # SSP arguments are as follows (indexed from 0,0, unbinned pixels)
        #     # - arg1 is the subarray Y position. This is the number of rows (in pixels) to the lower left corner of the desired subarray region.
        #     # - arg2 is the subarray X position. This is the number of columns (in pixels) to the lower left corner of the desired subarray region.
        #     # - arg3 is the bias region offset. This is the number of columns (in pixels) to the left edge of the desired bias region.
        #     int const windowEndCol = config.winStartCol + config.winWidth;
        #     int const afterDataGap = 5 + config.computeBinnedWidth(CCDWidth) - windowEndCol; # 5 skips some odd gunk
        #     runCommand("set window position", TIM_ID, SSP, config.winStartRow, config.winStartCol, afterDataGap);
        # }

        # int readoutAmpsCmdValue = ReadoutAmpsCmdValueMap.find(config.readoutAmps)->second;
        # runCommand("set readoutAmps", TIM_ID, SOS, readoutAmpsCmdValue, DON);

        # int readoutRateCmdValue = ReadoutRateCmdValueMap.find(config.readoutRate)->second;
        # runCommand("set readout rate", TIM_ID, SPS, readoutRateCmdValue, DON);

        # if (config.readoutAmps == ReadoutAmps::Quad) {
        #     int xSkip = ColBinXSkipMap_Quad.find(config.binFacCol)->second;
        #     int ySkip = config.binFacRow == 3 ? 1 : 0;
        #     runCommand("set xy skip for all amps", TIM_ID, SXY, xSkip, ySkip);
        # } else {
        #     int xSkip = ColBinXSkipMap_One.find(config.binFacCol)->second;
        #     xSkip = std::max(0, xSkip - config.winStartCol);
        #     runCommand("set xy skip for one amp", TIM_ID, SXY, xSkip, 0);
        # }

        # runCommand("set image width", TIM_ID, WRM, (Y_MEM | 1), config.getBinnedWidth());

        # runCommand("set image height", TIM_ID, WRM, (Y_MEM | 2), config.getBinnedHeight());

        self._config = config;

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

    def _assertIdle(self):
        if not self.state == Idle:
            raise RuntimeError("busy")




