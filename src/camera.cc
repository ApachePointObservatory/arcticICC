#include <cstdint>
#include <string>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>

#include "CArcDevice/ArcDefs.h"
#include "CArcFitsFile/CArcFitsFile.h"
#include "CArcDeinterlace/CArcDeinterlace.h"

#include "arcticICC/camera.h"

namespace {

    std::string const TimingBoardFileName = "/home/arctic/leach/tim.lod";

    // see ArcDefs.h and CommandDescription.pdf (you'll need both)
    // note that the two do not agree for any other options and we don't need them anyway
    std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsCmdValueMap {
        {arcticICC::ReadoutAmps::LL,   AMP_0},
        {arcticICC::ReadoutAmps::LR,   AMP_1},
        {arcticICC::ReadoutAmps::UR,   AMP_2},
        {arcticICC::ReadoutAmps::UL,   AMP_3},
        {arcticICC::ReadoutAmps::All,  AMP_ALL},
    };

// this results in undefined link symbols, so use direct constants for now. But why???
    // std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsDeinterlaceAlgorithmMap {
    //     {arcticICC::ReadoutAmps::LL,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::LR,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::UR,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::UL,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::All,   arc::deinterlace::CArcDeinterlace::DEINTERLACE_CCD_QUAD},
    // };

    std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsDeinterlaceAlgorithmMap {
        {arcticICC::ReadoutAmps::LL,    0},
        {arcticICC::ReadoutAmps::LR,    0},
        {arcticICC::ReadoutAmps::UR,    0},
        {arcticICC::ReadoutAmps::UL,    0},
        {arcticICC::ReadoutAmps::All,   3},
    };

    // The following was taken from Owl's SelectableReadoutSpeedCC.bsh
    // it uses an undocumented command "SPS"
    int const SPS = 0x535053;
    std::map<arcticICC::ReadoutRate, int> ReadoutRateCmdValueMap = {
        {arcticICC::ReadoutRate::Slow,   0x534C57},
        {arcticICC::ReadoutRate::Medium, 0x4D4544},
        {arcticICC::ReadoutRate::Fast,   0x465354},
    };

    /**
    Return the time interval, in fractional seconds, between two chrono steady_clock times

    based on http://www.cplusplus.com/reference/chrono/steady_clock/
    but it's not clear the cast is required; it may suffice to specify duration<double>
    */
    double elapsedSec(std::chrono::steady_clock::time_point const &tBeg, std::chrono::steady_clock::time_point const &tEnd) {
        return std::chrono::duration_cast<std::chrono::duration<double>>(tEnd - tBeg).count();
    }
}

namespace arcticICC {

    Camera::Camera() :
        _readoutAmps(ReadoutAmps::All),
        _readoutRate(ReadoutRate::Slow),
        _colBinFac(2),
        _rowBinFac(2),
        _winColStart(0),
        _winRowStart(0),
        _winWidth(CCDWidth),
        _winHeight(CCDHeight),
        _expName(),
        _expType(ExposureType::Object),
        _cmdExpSec(-1),
        _segmentExpSec(-1),
        _segmentStartTime(),
        _segmentStartValid(false),
        _device()
    {
        int const fullWidth = CCDWidth + XExtraPix;
        int const fullHeight = CCDHeight + YExtraPix;
        int const numBytes = fullWidth * fullHeight * sizeof(uint16_t);
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

        // set default configuration
        setReadoutAmps(ReadoutAmps::All);
        setReadoutRate(ReadoutRate::Medium);
        setBinFactor(2, 2);
    }

    Camera::~Camera() {
        if (_device.IsReadout()) {
            // abort readout, else the board will keep reading out, which ties it up
            _device.StopExposure();
        }
        _device.Close();
    }

    void Camera::startExposure(double expTime, ExposureType expType, std::string const &name) {
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
        _expType = expType;
        _cmdExpSec = expTime;
        _segmentExpSec = _cmdExpSec;
        _segmentStartTime = std::chrono::steady_clock::now();
        _segmentStartValid = true;
    }

    void Camera::pauseExposure() {
        if (getExposureState().state != StateEnum::Exposing) {
            throw std::runtime_error("no exposure to pause");
        }
        runCommand("pause exposure", TIM_ID, PEX);
        // decrease _segmentExpSec by the duration of the exposure segment just ended
        _segmentExpSec -= elapsedSec(_segmentStartTime, std::chrono::steady_clock::now());
        _segmentStartValid = false;    // indicates that _segmentStartTime is invalid
    }

    void Camera::resumeExposure() {
        if (getExposureState().state != StateEnum::Paused) {
            throw std::runtime_error("no paused exposure to resume");
        }
        runCommand("resume exposure`", TIM_ID, REX);
        _segmentStartTime = std::chrono::steady_clock::now();
        _segmentStartValid = true;
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
        } else if (!_segmentStartValid) {
            return ExposureState(StateEnum::Paused);
        } else if (_device.IsReadout()) {
            int totPix = getBinnedWidth() * getBinnedHeight();
            int numPixRead = _device.GetPixelCount();
            int numPixRemaining = std::max(totPix - numPixRead, 0);
            double fullReadTime = _readTime(totPix);
            double remReadTime = _readTime(numPixRemaining);
            return ExposureState(StateEnum::Reading, fullReadTime, remReadTime);
        } else if (static_cast<uint16_t *>(_device.CommonBufferVA())[0] == 0) {
            double segmentRemTime = _segmentExpSec - elapsedSec(_segmentStartTime, std::chrono::steady_clock::now());
            return ExposureState(StateEnum::Exposing, _cmdExpSec, segmentRemTime);
        } else {
            return ExposureState(StateEnum::ImageRead);
        }
    }

    void Camera::setBinFactor(int colBinFac, int rowBinFac) {
        std::cout << "setBinFactor(" << colBinFac << ", " << rowBinFac << ")\n";
        assertIdle();
        if (colBinFac < 1 or colBinFac > MaxBinFactor) {
            std::ostringstream os;
            os << "colBinFac=" << colBinFac << " < 1 or > " << MaxBinFactor;
            throw std::runtime_error(os.str());
        }
        if (rowBinFac < 1 or rowBinFac > MaxBinFactor) {
            std::ostringstream os;
            os << "rowBinFac=" << rowBinFac << " < 1 or > " << MaxBinFactor;
            throw std::runtime_error(os.str());
        }
        // if the following test fails: we have set set XExtraPix, YExtraPix or MaxBinFactor incorrectly,
        // or else decided to allow larger bin factors that simply don't work when reading out all amps
        if (_readoutAmps == ReadoutAmps::All) {
            // the number of binned rows and columns must be even
            if ((getUnbinnedWidth()  % (2 * colBinFac) != 0) ||
                (getUnbinnedHeight() % (2 * rowBinFac) != 0)) {
                std::ostringstream os;
                os << "reading all amplifiers, so the number of binned rows=" << (getUnbinnedWidth() / colBinFac)
                    << "and columns=" << (getUnbinnedHeight() / rowBinFac) << " must both be even";
                throw std::runtime_error(os.str());
            }
        }

        _device.SetBinning(getUnbinnedHeight(), getUnbinnedWidth(), rowBinFac, colBinFac);
        _rowBinFac = rowBinFac;
        _colBinFac = colBinFac;
    }

    void Camera::setFullWindow() {
        std::cout << "setFullWindow()\n";
        _device.UnSetSubArray(getBinnedHeight(), getUnbinnedWidth());
        _winColStart = 0;
        _winRowStart = 0;
        _winWidth = CCDWidth;
        _winHeight = CCDHeight;
    }

    void Camera::setWindow(int colStart, int rowStart, int width, int height) {
        std::cout << "setWindow(" << colStart << ", " << rowStart << ", " << width << ", " << height << ")\n";
        if (!canWindow()) {
            std::ostringstream os;
            os << "cannot window unless reading from a single amplifier; readoutAmps="
                << ReadoutAmpsNameMap.find(_readoutAmps)->second;
            throw std::runtime_error(os.str());
        }
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

        _device.SetImageSize(getBinnedHeight(), getBinnedWidth());

        // set subarray size; warning: this only works when reading from one amplifier
        // arguments are:
        // - arg1 is the bias region width (in pixels)
        // - arg2 is the subarray width (in pixels)
        // - arg3 is the subarray height (in pixels)
        runCommand("set window size", TIM_ID, SSS, OneAmpOverscan, width, height);

        // set subarray starting-point; warning: this only works when reading from one amplifier
        // SSP arguments are as follows (indexed from 0,0, unbinned pixels)
        // - arg1 is the subarray Y position. This is the number of rows (in pixels) to the lower left corner of the desired subarray region.
        // - arg2 is the subarray X position. This is the number of columns (in pixels) to the lower left corner of the desired subarray region.
        // - arg3 is the bias region offset. This is the number of columns (in pixels) to the left edge of the desired bias region.
        runCommand("set window position", TIM_ID, SSP, rowStart, colStart, CCDWidth);
    }

    void Camera::setReadoutAmps(ReadoutAmps readoutAmps) {
        std::cout << "setReadoutAmps(ReadoutAmps::" << ReadoutAmpsNameMap.find(readoutAmps)->second << ")\n";
        if (!isFullWindow() && !canWindow(readoutAmps)) {
            std::ostringstream os;
            os << "presently sub-windowing, which is not compatible with readoutAmps=" << ReadoutAmpsNameMap.find(_readoutAmps)->second;
            throw std::runtime_error(os.str());
        }
        assertIdle();
        int cmdValue = ReadoutAmpsCmdValueMap.find(readoutAmps)->second;
        runCommand("set readoutAmps", TIM_ID, SOS, cmdValue, DON);
        _readoutAmps = readoutAmps;
    }

    void Camera::setReadoutRate(ReadoutRate readoutRate) {
        std::cout << "setReadoutRate(ReadoutRate::" << ReadoutRateNameMap.find(readoutRate)->second << ")\n";
        assertIdle();
        int cmdValue = ReadoutRateCmdValueMap.find(readoutRate)->second;
        runCommand("set readout rate", TIM_ID, SPS, cmdValue, DON);
        _readoutRate = readoutRate;
    }

    void Camera::saveImage(double expTime) {
        std::cout << "saveImage(" << expTime << ")\n";
        if (getExposureState().state != StateEnum::ImageRead) {
            throw std::runtime_error("no image available to be read");
        }

        try {
            int deinterlaceAlgorithm = ReadoutAmpsDeinterlaceAlgorithmMap.find(_readoutAmps)->second;
            arc::deinterlace::CArcDeinterlace deinterlacer;
            std::cout << "deinterlacer.RunAlg(" << _device.CommonBufferVA() << ", " 
                <<  getBinnedHeight() << ", " << getBinnedWidth() << ", " << deinterlaceAlgorithm << ")" << std::endl;
            deinterlacer.RunAlg(_device.CommonBufferVA(), getBinnedHeight(), getBinnedWidth(), deinterlaceAlgorithm);


            arc::fits::CArcFitsFile cFits(_expName.c_str(), getBinnedHeight(), getBinnedWidth());

            std::string expTypeStr = ExposureTypeNameMap.find(_expType)->second;
            cFits.WriteKeyword(const_cast<char *>("EXPTYPE"), &expTypeStr, arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("exposure type"));

            cFits.WriteKeyword(const_cast<char *>("EXPTIME"), &expTime, arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("exposure time (sec)"));

            std::string readoutAmpsStr = ReadoutAmpsNameMap.find(_readoutAmps)->second;
            cFits.WriteKeyword(const_cast<char *>("READAMPS"), &readoutAmpsStr, arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("readout amplifier(s)"));

            std::string readoutRateStr = ReadoutRateNameMap.find(_readoutRate)->second;
            cFits.WriteKeyword(const_cast<char *>("READRATE"), &readoutRateStr, arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("readout rate"));

            cFits.Write(_device.CommonBufferVA());
            if (expTime < 0) {
                expTime = _cmdExpSec;
            }

            std::cout << "saved image as \"" << _expName << "\"\n";
        } catch(...) {
            _setIdle();
            throw;
        }
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
        _segmentStartValid = false;
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
