#include <cstdint>
#include <string>
#include <iostream>
#include <sstream>
#include <stdexcept>

#include "CArcDeinterlace.h"
#include "CArcFitsFile.h"
#include "ArcDefs.h"

#include "arcticICC/camera.h"

std::string const TimingBoardFileName = "tim.lod";

// The following was taken from Owl's SelectableReadoutSpeedCC.bsh
// it uses an undocumented command "SPS"
int const SPS = 0x535053;
std::map<arctic::ReadoutRate, int> ReadoutRateCmdValueMap = {
    {arctic::ReadoutRate::Slow,   0x534C57},
    {arctic::ReadoutRate::Medium, 0x4D4544},
    {arctic::ReadoutRate::Fast,   0x465354},
};

namespace arctic {

    Camera::Camera(int dataWidth, int dataHeight, int xOverscan) :
        dataWidth(dataWidth), dataHeight(dataHeight), xOverscan(xOverscan),
        _colBinFac(1), _rowBinFac(1),
        _winColStart(0), _winRowStart(0), _winWidth(dataWidth), _winHeight(dataHeight),
        _readoutRate(ReadoutRate::Slow),
        _cmdExpSec(-1), _segmentExpSec(-1), _segmentStartTime(0),
        _device()
    {
        if ((dataWidth < 1) || (dataHeight < 1)) {
            std::ostringstream os;
            os << "dataWidth=" << dataWidth << " and dataHeight=" << dataHeight << " must be positive";
            throw std::runtime_error(os.str());
        }
        if (xOverscan < 0) {
            std::ostringstream os;
            os << "xOverscan=" << xOverscan << " must be non-negative";
            throw std::runtime_error(os.str());
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

    Camera::~Camera() {
        _device.Close();
    }

    void Camera::startExposure(float expTime, ExposureType expType, std::string const &name) {
        assertIdle();
        if (expTime < 0) {
            std::ostringstream os;
            os << "exposure time=" << expTime << " must be non-negative";
            throw std::runtime_error(os.str());
        }
        if ((expType == ExposureType::Bias) && (expTime > 0)) {
            std::ostringstream os;
            os << "exposure time=" << expTime << " must be zero if expType=Bias";
            throw std::runtime_error(os.str());
        }

        // clear common buffer, so we know when new data arrives
        _device.FillCommonBuffer(0);

        bool openShutter = expType > ExposureType::Dark;
        _device.SetOpenShutter(openShutter);

        int expTimeMS = int(expTime*1000.0);
        std::ostringstream os;
        os << "Set exposure time to " << expTimeMS << " ms";
        runCommand(os.str(), TIM_ID, SET, expTimeMS);

        runCommand("start exposure", TIM_ID, SEX);
        _expName = name;
        _cmdExpSec = expTime;
        _segmentExpSec = _cmdExpSec;
        _segmentStartTime = time(NULL);
    }

    void Camera::pauseExposure() {
        if (getExposureState().state != StateEnum::Exposing) {
            throw std::runtime_error("no exposure to pause");
        }
        runCommand("pause exposure", TIM_ID, PEX);
        double segmentElapsedTime = difftime(time(NULL), _segmentStartTime);
        _segmentExpSec = std::max(0.0, _segmentExpSec - segmentElapsedTime);
        _segmentStartTime = 0; // indicate that the exposure is paused
    }

    void Camera::resumeExposure() {
        if (getExposureState().state != StateEnum::Paused) {
            throw std::runtime_error("no paused exposure to resume");
        }
        runCommand("resume exposure`", TIM_ID, REX);
        _segmentStartTime = time(NULL);
    }

    void Camera::abortExposure() {
        if (!isBusy()) {
            throw std::runtime_error("no exposure to abort");
        }
        _device.StopExposure();
        _setIdle();
    }

    void Camera::stopExposure() {
        auto expState = getExposureState();
        if (!expState.isBusy()) {
            throw std::runtime_error("no exposure to stop");
        }
        if (expState.state == StateEnum::Reading || expState.remTime < 0.1) {
            // if reading out or nearly ready to read out then it's too late to stop; let the exposure end normally
            return;
        }
        runCommand("stop exposure", TIM_ID, SET, 0);
    }

    ExposureState Camera::getExposureState() {
        if (_cmdExpSec < 0) {
            return ExposureState(StateEnum::Idle);
        } else if (_segmentStartTime == 0) {
            return ExposureState(StateEnum::Paused);
        } else if (_device.IsReadout()) {
            int totPix = getImageWidth() * getImageHeight();
            int numPixRead = _device.GetPixelCount();
            int numPixRemaining = std::max(totPix - numPixRead, 0);
            double fullReadTime = _readTime(totPix);
            double remReadTime = _readTime(numPixRemaining);
            return ExposureState(StateEnum::Reading, fullReadTime, remReadTime);
        } else if (static_cast<uint16_t *>(_device.CommonBufferVA())[0] == 0) {
            double segmentRemTime = difftime(time(NULL), _segmentStartTime);
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
            throw std::runtime_error(os.str());
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

    void Camera::setWindow(int colStart, int rowStart, int width, int height) {
        assertIdle();
        if (colStart < 0 || colStart >= dataWidth) {
            std::ostringstream os;
            os << "colStart=" << colStart << " < 0 or >= " << dataWidth;
            throw std::runtime_error(os.str());
        }
        if (rowStart < 0 || rowStart >= dataHeight) {
            std::ostringstream os;
            os << "rowStart=" << rowStart << " < 0 or >= " << dataHeight;
            throw std::runtime_error(os.str());
        }
        if (width < 1 or width > dataWidth) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << dataWidth;
            throw std::runtime_error(os.str());
        }
        if (height < 1 or height > dataHeight) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << dataHeight;
            throw std::runtime_error(os.str());
        }

        // clear current window, to avoid asking for a window that is off the CCD
        runCommand("clear old window", TIM_ID, SSS, 0, 0, 0);

        // set subarray size
        runCommand("set window size", TIM_ID, SSS, xOverscan, width, height);

        // set subarray starting-point
        runCommand("set window position", TIM_ID, SSP, colStart, rowStart, dataWidth);
    }

    ReadoutRate Camera::getReadoutRate() const {
        return _readoutRate;
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
        arc::fits::CArcFitsFile cFits(_expName.c_str(), getImageHeight(), getImageWidth());
        cFits.Write(_device.CommonBufferVA());
        if (expTime < 0) {
            expTime = _cmdExpSec;
        }
        cFits.WriteKeyword(const_cast<char *>("EXPTIME"), &expTime, arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("exposure time (sec)"));
        std::string expTypeStr = ExposureTypeMap.find(_expType)->second;
        cFits.WriteKeyword(const_cast<char *>("EXPTYPE"), &expTypeStr, arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("exposure type"));
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

    void Camera::assertIdle() {
        if (this->isBusy()) {
            throw std::runtime_error("busy");
        }
    }

    double Camera::_readTime(int nPix) const {
        return nPix * ReadoutRateSecMap.find(_readoutRate)->second;
    }

    void Camera::_setIdle() {
        _cmdExpSec = -1;
        _segmentExpSec = -1;
        _segmentStartTime = 0;
        _device.FillCommonBuffer(0);
    }

    void Camera::runCommand(std::string const &descr, int arg0, int arg1, int arg2, int arg3, int arg4) {
        int retVal = _device.Command(arg0, arg1, arg2, arg3, arg4);
        if (retVal != DON) {
            std::ostringstream os;
            os << descr << " failed with retVal=" << retVal;
            throw std::runtime_error(os.str());
        }
    }
} // namespace