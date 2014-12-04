#include <cstdint>
#include <string>
#include <iostream>
#include <sstream>
#include <stdexcept>

#include "CArcDevice/ArcDefs.h"
#include "CArcFitsFile/CArcFitsFile.h"

#include "arcticICC/camera.h"

std::string const TimingBoardFileName = "/home/arctic/leach/tim.lod";

// The following was taken from Owl's SelectableReadoutSpeedCC.bsh
// it uses an undocumented command "SPS"
int const SPS = 0x535053;
std::map<arctic::ReadoutRate, int> ReadoutRateCmdValueMap = {
    {arctic::ReadoutRate::Slow,   0x534C57},
    {arctic::ReadoutRate::Medium, 0x4D4544},
    {arctic::ReadoutRate::Fast,   0x465354},
};

namespace arctic {

    Camera::Camera() :
        _colBinFac(1), _rowBinFac(1),
        _winColStart(0), _winRowStart(0), _winWidth(CCDWidth), _winHeight(CCDHeight),
        _readoutRate(ReadoutRate::Slow),
        _cmdExpSec(-1), _segmentExpSec(-1), _segmentStartTime(0),
        _device()
    {
        int fullHeight = CCDHeight; // controller does not support y overscan
        int fullWidth = CCDWidth + (XNumAmps * XOverscan);
        int numBytes = fullWidth * fullHeight * sizeof(uint16_t);
        std::cout << "arc::device::CArcPCIe::FindDevices()\n";
        arc::device::CArcPCIe::FindDevices();
        std::cout << "_device.DeviceCount()=" << _device.DeviceCount() << std::endl;
        if (_device.DeviceCount() < 1) {
            throw std::runtime_error("no Leach controller found");
        }
        std::cout << "_device.Open(0, " << numBytes << ")\n";
        _device.Open(0, numBytes);
        std::cout << "_device.IsControllerConnected()" << std::endl;
        if (!_device.IsControllerConnected()) {
            throw std::runtime_error("Controller is disconnected or powered off");
        }
        std::cout << "_device.SetupController(true, true, true, " << fullHeight << ", " << fullWidth << ", \"" << TimingBoardFileName.c_str() << "\")\n";
        _device.SetupController(
            true,       // reset?
            true,       // send TDLS to the PCIe board and any board whose .lod file is not NULL?
            true,       // power on the controller?
            fullHeight, // image height
            fullWidth,  // image width
            TimingBoardFileName.c_str() // timing board file to load
        );

        runCommand("set readout mode to quad", TIM_ID, SOS, AMP_ALL);        

        // std::cout << "setReadoutRate(ReadoutRate::Slow);\n";
        // setReadoutRate(ReadoutRate::Slow); // force a value so we know what it is
    }

    Camera::~Camera() {
        if (_device.IsReadout()) {
            // abort readout, else the board will keep reading out, which ties it up
            _device.StopExposure();
        }
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
        std::cout << "_device.FillCommonBuffer(0)\n";
        _device.FillCommonBuffer(0);

        bool openShutter = expType > ExposureType::Dark;
        std::cout << "_device.SetOpenShutter(" << openShutter << ")\n";
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
        std::cout << "_device.StopExposure()\n";
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
            double segmentRemTime = _segmentExpSec - difftime(time(NULL), _segmentStartTime);
            return ExposureState(StateEnum::Exposing, _cmdExpSec, segmentRemTime);
        } else {
            return ExposureState(StateEnum::ImageRead);
        }
    }

    void Camera::setBinFactor(int colBinFac, int rowBinFac) {
        assertIdle();
        if (colBinFac < 1 or colBinFac > CCDWidth) {
            std::ostringstream os;
            os << "colBinFac=" << colBinFac << " < 1 or > " << CCDWidth;
            throw std::runtime_error(os.str());
        }
        if (rowBinFac < 1 or rowBinFac > CCDHeight) {
            std::ostringstream os;
            os << "rowBinFac=" << rowBinFac << " < 1 or > " << CCDHeight;
            throw std::runtime_error(os.str());
        }

        runCommand("set column bin factor", TIM_ID, WRM, (Y_MEM | 0x5), colBinFac);
        _colBinFac = colBinFac;

        runCommand("set row bin factor", TIM_ID, WRM, (Y_MEM | 0x6), rowBinFac);
        _rowBinFac = rowBinFac;
    }

    void Camera::setWindow(int colStart, int rowStart, int width, int height) {
        assertIdle();
        if (colStart < 0 || colStart >= CCDWidth) {
            std::ostringstream os;
            os << "colStart=" << colStart << " < 0 or >= " << CCDWidth;
            throw std::runtime_error(os.str());
        }
        if (rowStart < 0 || rowStart >= CCDHeight) {
            std::ostringstream os;
            os << "rowStart=" << rowStart << " < 0 or >= " << CCDHeight;
            throw std::runtime_error(os.str());
        }
        if (width < 1 or width > CCDWidth) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << CCDWidth;
            throw std::runtime_error(os.str());
        }
        if (height < 1 or height > CCDHeight) {
            std::ostringstream os;
            os << "width=" << width << " < 1 or > " << CCDHeight;
            throw std::runtime_error(os.str());
        }

        // clear current window, to avoid asking for a window that is off the CCD
        runCommand("clear old window", TIM_ID, SSS, 0, 0, 0);

        // set subarray size
        // arguments are:
        // - arg2 is the bias region width (in pixels)
        //          what does this mean for a CCC with multiple amplifiers???!!!
        // - arg3 is the subarray width (in pixels)
        // - arg3 is the subarray height (in pixels)
        runCommand("set window size", TIM_ID, SSS, XOverscan, width, height);

        // set subarray starting-point
        // SSP arguments are as follows (indexed from 0,0, unbinned pixels)
        // - arg2 is the subarray Y position. This is the number of rows (in pixels) to the lower left corner of the desired subarray region.
        // - arg3 is the subarray X position. This is the number of columns (in pixels) to the lower left corner of the desired subarray region.
        // - arg3 is the bias region offset. This is the number of columns (in pixels) to the left edge of the desired bias region.
        //          what does this mean for a CCC with multiple amplifiers???!!!
        runCommand("set window position", TIM_ID, SSP, rowStart, colStart, CCDWidth);
    }

    ReadoutRate Camera::getReadoutRate() const {
        return _readoutRate;
    }

    void Camera::setReadoutRate(ReadoutRate readoutRate) {
        assertIdle();
        int cmdValue = ReadoutRateCmdValueMap.find(readoutRate)->second;
        runCommand("set readout rate", TIM_ID, SPS, cmdValue, DON);
        _readoutRate = readoutRate;
    }

    void Camera::saveImage(double expTime) {
        if (getExposureState().state != StateEnum::ImageRead) {
            throw std::runtime_error("no image available to be read");
        }
        arc::deinterlace::CArcDeinterlace deinterlacer;
        std::cout << "deinterlacer.RunAlg(" << _device.CommonBufferVA() << ", " <<  getImageHeight() << ", " << getImageWidth() << ", " << DeinterlaceAlgorithm << ")" << std::endl;
        deinterlacer.RunAlg(_device.CommonBufferVA(), getImageHeight(), getImageWidth(), DeinterlaceAlgorithm);

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
        return nPix / ReadoutRateFreqMap.find(_readoutRate)->second;
    }

    void Camera::_setIdle() {
        _cmdExpSec = -1;
        _segmentExpSec = -1;
        _segmentStartTime = 0;
        std::cout << "_device.FillCommonBuffer(0)\n";
        _device.FillCommonBuffer(0);
    }

    void Camera::runCommand(std::string const &descr, int boardID, int cmd, int arg1, int arg2, int arg3) {
        if ((boardID != TIM_ID) && (boardID != UTIL_ID) && (boardID != PCI_ID)) {
            std::ostringstream os;
            os << std::hex << "unknown boardID=0x" << boardID;
            throw std::runtime_error(os.str());
        }
        std::cout << std::hex << "_device.Command("
            <<  "0x" << boardID
            << ", 0x" << cmd
            << ", 0x" << arg1
            << ", 0x" << arg2
            << ", 0x" << arg3
            << "): " << descr << std::dec << std::endl;
        int retVal = _device.Command(boardID, cmd, arg1, arg2, arg3);
        if (retVal != DON) {
            std::ostringstream os;
            os << descr << " failed with retVal=" << retVal;
            throw std::runtime_error(os.str());
        }
    }

} // namespace