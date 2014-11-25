#include <string>
#include <iostream>
#include <sstream>
#include <stdexcept>

// fix these as needed
#include "CArcDevice.h"
#include "CArcPCIe.h"
#include "CArcDeinterlace.h"
#include "CArcFitsFile.h"
#include "CExpIFace.h"

#include "arcticICC/camera.h"

std::string const TimingBoardFileName = "tim.lod";

// The following was taken from Owl's SelectableReadoutSpeedCC.bsh
// it uses an undocumented command "SPS"
int const SPS = 0x535053;
std::map<int, int> ReadoutRateCmdValueMap = {
    {ReadoutRate::Slow,   0x534C57},
    {ReadoutRate::Medium, 0x4D4544},
    {ReadoutRate::Fast,   0x465354},
}

namespace arctic {

    Camera::Camera(int dataWidth, int dataHeight, int xOverscan, int yOverscan) :
        dataWidth(dataWidth), dataHeight(dataHeight), xOverscan(xOverscan),
        _colBinFac(1), _rowBinFac(1),
        _winColStart(0), _winRowStart(0), _winWidth(dataWidth), _winHeight(dataHeight),
        _readoutRate(ReadoutRate::Slow),
        _cmdExpSec(-1), _segmentExpSec(-1), _segmentStartTime(0),
        _device()
    {
        if ((dataWidth < 1) || (dataHeight < 1)) {
            std::ostringstream os;
            os << "width=" << width << " and height=" << height " must be positive";
            throw std::runtime_error(os.str())
        }
        if (xOverscan < 0) {
            std::ostringstream os;
            os << "xOverscan=" << xOverscan << " must be non-negative";
            throw std::runtime_error(os.str())
        }

        int fullHeight = dataHeight; // controller does not support y overscan
        int fullWidth = dataWidth + xOverscan;
        int numBytes = fullWidth * fullHeight * 2; // 16 bits/pixel
        _device.Open(0, fullHeight, fullWidth);
        _device.MapCommonBuffer(numBytes);
        _device.SetupController(
            true,       // reset?
            true,       // send TDLS to the PCIe board and any board whose .lod file is not NULL?
            true,       // power on the controller?
            fullHeight, // image height
            fullWidth,  // image width
            TimingBoardFileName.c_str() // timing board file to load
        );
        setReadoutRate(ReadoutRate::Slow); // force a value so we know what it is
    }

    ~Camera::Camera() {
        _device.Close();
    }

    void startExposure(float expTime, ExposureType expType, std::string const &name) {
        assertIdle();
        if (expTime < 0) {
            std::ostringstream os;
            os << "exposure time=" << expTime << " must be non-negative";
            throw std::runtime_error(os.str())
        }
        if ((expType == ExposureType::Bias) && (expTime > 0)) {
            std::ostringstream os;
            os << "exposure time=" << expTime << " must be zero if expType=Bias";
            throw std::runtime_error(os.str())
        }

        // clear common buffer, so we know when new data arrives
        _device.FillCommonBuffer(0);

        bool openShutter = expType > ExposureType::Dark;
        _device.SetOpenShutter(openShutter);

        int expTimeMS = int(expTime*1000.0);
        std::ostringstream os;
        os << "Set exposure time to " << expTimeMS << " ms" << expTimeRetVal;
        runCommand(os.str(), TIM_ID, SET, expTimeMS);

        runCommand("start exposure", TIM_ID, SEX);
        _expName = name;
        _cmdExpSec = expTime;
        _segmentExpSec = _cmdExpSec;
        _segmentStartTime = time();
    }

    void Camera::pauseExposure() {
        if (getExposureState().state != StateEnum::Exposing) {
            throw std::runtime_error("no exposure to pause");
        }
        runCommand("pause exposure", TIM_ID, PEX);
        double segmentElapsedTime = difftime(time(), _segmentStartTime);
        _segmentExpSec = max(0, _segmentExpSec - segmentElapsedTime);
        _segmentStartTime = 0; // indicate that the exposure is paused
    }

    void Camera::resumeExposure() {
        if (getExposureState().state != StateEnum::Paused) {
            throw std::runtime_error("no paused exposure to resume");
        }
        runCommand("resume exposure`", TIM_ID, REX);
        _segmentStartTime = time();
    }

    void Camera::abortExposure() {
        if (!isBusy()) {
            throw std::runtime_error("no exposure to abort");
        }
        _device.StopExposure()
        _setIdle();
    }

    void Camera::stopExposure() {
        auto expState = getExposureState();
        if (ExposingEnumSet.count(expState) == 0) {
            throw std::runtime_error("no exposure to stop");
        }
        if (expState == StateEnum::Reading || expState.remTime < 0.1) {
            // if reading out or nearly ready to read out then it's too late to stop; let the exposure end normally
            return;
        }
        runCommand("stop exposure", TIM_ID, SET, 0);
    }

    ExposureState Camera::getExposureState() const {
        if (_cmdExpSec < 0) {
            return ExposureState(StateEnum::Idle);
        else if (_segmentStartTime == 0) {
            return ExposureState(StateEnum::Paused);
        else if (_device.IsReadout()) {
            int totPix = getImageWidth() * getImageHeight();
            int numPixRead = _device.GetPixelCount();
            int numPixRemaining = std::max(totPix - numPixRead, 0);
            double fullReadTime = _readTime(fullNumPix);
            double remReadTime = _readTime(numPixRemaining);
            return ExposureState(StateEnum::Reading, fullReadTime, remReadTime);
        } else if (_device.CommonBufferVA()[0] == 0) {
            double segmentRemTime = difftime(time(), _segmentStartTime);
            return ExposureState(StateEnum::Exposing, _cmdExpSec, segmentRemTime);
        } else {
            return ExposureState(StateEnum::ImageRead);
        }
    }

    void Camera::setBinFactor(int colBinFac, int rowBinFac) {
        assertIdle();
        if (colBinFac < 1 or colBinFac > dataWidth) {
            std::ostringstream os;
            os << "colBinFac=" << colBinFac << " < 1 or > " << dataWidth;
            throw std::runtime_error
        }
        if (rowBinFac < 1 or rowBinFac > dataHeight) {
            std::ostringstream os;
            os << "rowBinFac=" << rowBinFac << " < 1 or > " << dataHeight;
            throw std::runtime_error(os.str());
        }

        runCommand("set column bin factor", TIM_ID, WRM, (Y_MEM | 0x5), colBinFac);
        _colBinFac = colBinFac;

        runCommand("set row bin factor", TIM_ID, WRM, (Y_MEM | 0x6), rowBinFac);
        _rowBinFac = rowBinFac;
    }

    void Camera::setWindow(int colStart, rowStart, int width, int height) {
        assertIdle();
        if (colStart < 0 || colStart >= dataWidth) {
            std::ostringstream os;
            os << "colStart=" << colStart << " < 0 or >= " << dataWidth;
            throw std::runtime_error
        }
        if (rowStart < 0 || rowStart >= dataHeight) {
            std::ostringstream os;
            os << "rowStart=" << rowStart << " < 0 or >= " << dataHeight;
            throw std::runtime_error
        }
        if (width < 1 or width > dataWidth) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << dataWidth;
            throw std::runtime_error
        }
        if (height < 1 or height > dataHeight) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << dataHeight;
            throw std::runtime_error
        }

        // clear current window, to avoid asking for a window that is off the CCD
        runCommand("clear old window", TIM_ID, SSS, 0, 0, 0);

        // set subarray size
        runCommand("set window size", TIM_ID, SSS, xOverscan, width, height);

        // set subarray starting-point
        runCommand("set window position", TIM_ID, SSP, colStart, rowStart, dataWidth);
    }

    ReadoutRate Camera::getReadoutRate() const {
        return _readoutRate
    }

    void Camera::setReadoutRate(ReadoutRate readoutRate) {
        assertIdle();
        int cmdValue = ReadoutRateCmdValueMap.find(readoutRate)->second;
        runCommand("set readout rate", SPS, cmdValue);
        _readoutRate = readoutRate;
    }

    void Camera::saveImage(double expTime) {
        if (getExposureState().state != StateEnum::ImageRead) {
            throw std::runtime_error("no image available to be read");
        }
        CArcFitsFile cFits(_expName.c_str(), getCameraHeight(), getCameraWidth());
        cFits.Write(_device.CommonBufferVA());
        if (expTime < 0) {
            expTime = _cmdExpSec;
        }
        cFits.WriteKeyword("EXPTIME", &expTime, CArcFitsFile.FITS_DOUBLE_KEY, "exposure time (sec)");
        std::string expTypeStr = ExposureTypeMap.find(_expType)->second;
        cFits.WriteKeyword("EXPTYPE", expTypeStr.c_str(), CArcFitsFile.FITS_STRING_KEY, "exposure type");
        _setIdle();
    }

    void Camera::openShutter() {
        assertIdle();
        runCommand("open shutter", TIM_ID, OSH);
    }

    void Camera::closeShutter() {
        assertIdle();
        runCommand("close shutter", TIM_ID, CSH);
    }

// private methods

    void Camera::assertIdle() const {
        if (this->isBusy()) {
            raise std::runtime_error("busy");
        }
    }

    void Camera::_setIdle() {
        _cmdExpSec = -1;
        _segmentExpSec = -1;
        _segmentStartTime = 0;
        _device.FillCommonBuffer(0);
    }

    void Camera::runCommand(std::string const &descr, int arg0=0, int arg1=0, int arg2=0, int arg3=0) {
        int retVal = _device.Command(arg0, arg1, arg2, arg3);
        if (retVal != DON) {
            std::ostringstream os;
            os << descr << " failed with retVal=" << retVal;
            throw std::runtime_error(os.str());
        }
    }
} // namespace