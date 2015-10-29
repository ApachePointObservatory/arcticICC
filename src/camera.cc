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
    int const XBinnedPrescanPerAmp = 2;     // width of x prescan region, in binned pixels (if it can be fixed)
                                        // this is the remaining prescan after removing what we can
                                        // using the SXY (skip X,Y) command
    int const YQuadBorder = 2;          // border between Y amp images when using quad readout

    std::string const TimingBoardFileName = "/home/arctic/leach/tim.lod";

    // see ArcDefs.h and CommandDescription.pdf (you'll need both)
    // note that the two do not agree for any other options and we don't need them anyway
    std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsCmdValueMap {
        {arcticICC::ReadoutAmps::LL,   AMP_0},
        {arcticICC::ReadoutAmps::LR,   AMP_1},
        {arcticICC::ReadoutAmps::UR,   AMP_2},
        {arcticICC::ReadoutAmps::UL,   AMP_3},
        {arcticICC::ReadoutAmps::Quad, AMP_ALL}
    };

    // list of readout amps, in no particular order
    // std::vector<arcticICC::ReadoutAmps> ReadoutAmpList {
    //     arcticICC::ReadoutAmps::LL,
    //     arcticICC::ReadoutAmps::LR,
    //     arcticICC::ReadoutAmps::UR,
    //     arcticICC::ReadoutAmps::UL
    // };

// this results in undefined link symbols, so use direct constants for now. But why???
    // std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsDeinterlaceAlgorithmMap {
    //     {arcticICC::ReadoutAmps::LL,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::LR,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::UR,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::UL,    arc::deinterlace::CArcDeinterlace::DEINTERLACE_NONE},
    //     {arcticICC::ReadoutAmps::Quad,  arc::deinterlace::CArcDeinterlace::DEINTERLACE_CCD_QUAD},
    // };

    std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsDeinterlaceAlgorithmMap {
        {arcticICC::ReadoutAmps::LL,    0},
        {arcticICC::ReadoutAmps::LR,    0},
        {arcticICC::ReadoutAmps::UR,    0},
        {arcticICC::ReadoutAmps::UL,    0},
        {arcticICC::ReadoutAmps::Quad,  3}
    };

    std::map<int, int> ColBinXSkipMap_One {
        {1, 4},
        {2, 4},
        {3, 3},
        {4, 4}
    };

    std::map<int, int> ColBinXSkipMap_Quad {
        {1, 4},
        {2, 4},
        {3, 3},
        {4, 4}
    };

    // SPS <rate> command: set readout rate
    // The following was taken from Owl's SelectableReadoutSpeedCC.bsh
    int const SPS = 0x535053;   // ASCII for SPS
    std::map<arcticICC::ReadoutRate, int> ReadoutRateCmdValueMap = {
        {arcticICC::ReadoutRate::Slow,   0x534C57}, // ASCII for SLW
        {arcticICC::ReadoutRate::Medium, 0x4D4544}, // ASCII for MED
        {arcticICC::ReadoutRate::Fast,   0x465354}, // ASCII for FST
    };

    // SXY <cols> <rows> command: set initial number of rows and columns to skip
    // Use as needed when binning in quad mode to make sure the last row and column of data is purely data,
    // rather than a mix of data and overscan; otherwise use 0,0
    int const SXY = 0x535859;   // ASCII for  SXY

    /**
    Format a Leach controller command as a string of three capital letters

    If the int cannot be formatted that way then return it in hex format
    */
    std::string formatCmd(int cmd) {
        if ((cmd > 0) && (cmd <= 0xFFFFFF)) {
            std::ostringstream os;
            for (int i = 2; i >= 0; --i) {
                char c = (cmd >> (i*8)) & 0xFF;
                if ((c < 'A') || (c > 'Z')) {
                    goto useHex;
                }
                os << c;
            }
            return os.str();
        }

        useHex:
        std::ostringstream hexos;
        hexos << std::hex << "0x" << cmd;
        return hexos.str();
    }

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
    CameraConfig::CameraConfig() :
        readoutAmps(ReadoutAmps::LL),
        readoutRate(ReadoutRate::Medium),
        binFacCol(2),
        binFacRow(2),
        winStartCol(0),
        winStartRow(0),
        winWidth(CCDWidth/2),
        winHeight(CCDHeight/2)
    {}

    std::ostream &operator<<(std::ostream &os, CameraConfig const &config) {
        os << "CameraConfig(readoutAmps=" << ReadoutAmpsNameMap.find(config.readoutAmps)->second
            << ", readoutRate=" << ReadoutRateNameMap.find(config.readoutRate)->second
            << ", binFacCol=" << config.binFacCol
            << ", binFacRow=" << config.binFacRow
            << ", winStartCol=" << config.winStartCol
            << ", winStartRow=" << config.winStartRow
            << ", winWidth=" << config.winWidth
            << ", winHeight=" << config.winHeight
            << ")";
    }

    void CameraConfig::assertValid() const {
        std::cout << "assertValid: isFullWindow=" << isFullWindow() << "; canWindow=" << canWindow() << std::endl;
        if (!isFullWindow() && !canWindow()) {
            std::ostringstream os;
            os << "cannot window unless reading from a single amplifier; readoutAmps="
                << ReadoutAmpsNameMap.find(readoutAmps)->second;
            throw std::runtime_error(os.str());
        }
        if (binFacCol < 1 or binFacCol > MaxBinFactor) {
            std::ostringstream os;
            os << "binFacCol=" << binFacCol << " < 1 or > " << MaxBinFactor;
            throw std::runtime_error(os.str());
        }
        if (binFacRow < 1 or binFacRow > MaxBinFactor) {
            std::ostringstream os;
            os << "binFacRow=" << binFacRow << " < 1 or > " << MaxBinFactor;
            throw std::runtime_error(os.str());
        }

        int const binnedCCDWidth = computeBinnedWidth(CCDWidth);
        int const binnedCCDHeight = computeBinnedHeight(CCDHeight);
        if ((winStartCol < 0) || (winStartCol >= binnedCCDWidth)) {
            std::ostringstream os;
            os << "winStartCol=" << winStartCol << " < 0 or >= " << binnedCCDWidth;
            throw std::runtime_error(os.str());
        }
        if ((winStartRow < 0) || (winStartRow >= binnedCCDHeight)) {
            std::ostringstream os;
            os << "winStartRow=" << winStartRow << " < 0 or >= " << binnedCCDHeight;
            throw std::runtime_error(os.str());
        }
        if ((winWidth < 1) || (winWidth > binnedCCDWidth - winStartCol)) {
            std::ostringstream os;
            os << "winWidth=" << winWidth << " < 1 or > " << binnedCCDWidth - winStartCol;
            throw std::runtime_error(os.str());
        }
        if ((winHeight < 1) || (winHeight > binnedCCDHeight - winStartRow)) {
            std::ostringstream os;
            os << "winHeight=" << winHeight << " < 1 or > " << binnedCCDHeight - winStartRow;
            throw std::runtime_error(os.str());
        }

        // if the following test fails we have mis-set some parameter or are mis-computing getBinnedWidth or getBinnedHeight
        if (getNumAmps() > 1) {
            // the number of binned rows and columns must be even
            if ((getBinnedWidth() % 2 != 0) || (getBinnedHeight() % 2 != 0)) {
                std::ostringstream os;
                os << "Bug: reading from multiple amplifiers, so the binned width=" << getBinnedWidth()
                    << " and height=" << getBinnedHeight() << " must both be even";
                throw std::runtime_error(os.str());
            }
        }
    }

    int CameraConfig::getBinnedWidth() const {
        // Warning: if you change this code, also update getMaxWidth
        int xPrescan = XBinnedPrescanPerAmp * ((getNumAmps() > 1) ? 2 : 1);
        return winWidth + xPrescan + computeBinnedWidth(XOverscan);
    }

    int CameraConfig::getMaxWidth() {
        return CCDWidth + (2 * XBinnedPrescanPerAmp) + XOverscan;
    }

    int CameraConfig::getBinnedHeight() const {
        // Warning: if you change this code, also update getMaxHeight
        return winHeight + ((getNumAmps() > 1) ? YQuadBorder : 0);
    }

    int CameraConfig::getMaxHeight() {
        return CCDHeight + YQuadBorder;
    }


    Camera::Camera() :
        _config(),
        _expName(),
        _expType(ExposureType::Object),
        _cmdExpSec(-1),
        _estExpSec(-1),
        _segmentExpSec(-1),
        _segmentStartTime(),
        _segmentStartValid(false),
        _device()
    {
        int const fullWidth = CameraConfig::getMaxWidth();
        int const fullHeight = CameraConfig::getMaxHeight();
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
        setConfig(_config);
        _setIdle();
    }

    Camera::~Camera() {
        if (_device.IsReadout()) {
            // abort readout, else the board will keep reading out, which ties it up
            _device.StopExposure();
        }
        _device.Close();
    }

    void Camera::startExposure(double expTime, ExposureType expType, std::string const &name) {
        _assertIdle();
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
        _clearBuffer();

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
        _estExpSec = -1;
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
        double segmentSec = elapsedSec(_segmentStartTime, std::chrono::steady_clock::now());
        _segmentExpSec -= segmentSec;
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
        } else if (expState.state == StateEnum::Paused) {
            // stop a paused exposure; _segmentExpSec contains the remaining time for a full exposure
            _estExpSec = std::max(0.0, _cmdExpSec - _segmentExpSec);
        } else if (expState.state == StateEnum::Exposing) {
            // stop an active exposure
            double segmentDuration = elapsedSec(_segmentStartTime, std::chrono::steady_clock::now());
            double missingTime = _segmentExpSec - segmentDuration;
            _estExpSec = std::max(0.0, _cmdExpSec - missingTime);
        }
        runCommand("stop exposure", TIM_ID, SET, 0);
    }

    ExposureState Camera::getExposureState() {
        if (_cmdExpSec < 0) {
            return ExposureState(StateEnum::Idle);
        } else if (!_segmentStartValid) {
            return ExposureState(StateEnum::Paused);
        } else if (_device.IsReadout()) {
            _bufferCleared = false; // when no longer reading, makes sure the next state is ImageRead, not Exposing
            int totPix = _config.getBinnedWidth() * _config.getBinnedHeight();
            int numPixRead = _device.GetPixelCount();
            int numPixRemaining = std::max(totPix - numPixRead, 0);
            double fullReadTime = _estimateReadTime(totPix);
            double remReadTime = _estimateReadTime(numPixRemaining);
            if (_estExpSec < 0) {
                // exposure finished normally (instead of being stopped early); assume it was the right length
                _estExpSec = _cmdExpSec;
            }
            return ExposureState(StateEnum::Reading, fullReadTime, remReadTime);
        } else if (_bufferCleared && static_cast<uint16_t *>(_device.CommonBufferVA())[0] == 0) {
            // the && above helps in case getExposureState was not called often enough to clear _bufferCleared
            double segmentRemTime = _segmentExpSec - elapsedSec(_segmentStartTime, std::chrono::steady_clock::now());
            return ExposureState(StateEnum::Exposing, _cmdExpSec, segmentRemTime);
        } else {
            return ExposureState(StateEnum::ImageRead);
        }
    }

    void Camera::setConfig(CameraConfig const &config) {
        std::cout << "setConfig(" << config << ")\n";
        config.assertValid();
        _assertIdle();

        runCommand("set col bin factor",  TIM_ID, WRM, ( Y_MEM | 0x5 ), config.binFacCol);

        runCommand("set row bin factor",  TIM_ID, WRM, ( Y_MEM | 0x6 ), config.binFacRow);

        if (config.isFullWindow()) {
            runCommand("set full window", TIM_ID, SSS, 0, 0, 0);
        } else {
            // set subarray size; warning: this only works when reading from one amplifier
            // arguments are:
            // - arg1 is the bias region width (in pixels)
            // - arg2 is the subarray width (in pixels)
            // - arg3 is the subarray height (in pixels)
            int const xExtraPix = config.getBinnedWidth() - config.winWidth;
            runCommand("set window size", TIM_ID, SSS, xExtraPix, config.winWidth, config.winHeight);

            // set subarray starting-point; warning: this only works when reading from one amplifier
            // SSP arguments are as follows (indexed from 0,0, unbinned pixels)
            // - arg1 is the subarray Y position. This is the number of rows (in pixels) to the lower left corner of the desired subarray region.
            // - arg2 is the subarray X position. This is the number of columns (in pixels) to the lower left corner of the desired subarray region.
            // - arg3 is the bias region offset. This is the number of columns (in pixels) to the left edge of the desired bias region.
            int const windowEndCol = config.winStartCol + config.winWidth;
            int const afterDataGap = 5 + config.computeBinnedWidth(CCDWidth) - windowEndCol; // 5 skips some odd gunk
            runCommand("set window position", TIM_ID, SSP, config.winStartRow, config.winStartCol, afterDataGap);
        }

        int readoutAmpsCmdValue = ReadoutAmpsCmdValueMap.find(config.readoutAmps)->second;
        runCommand("set readoutAmps", TIM_ID, SOS, readoutAmpsCmdValue, DON);

        int readoutRateCmdValue = ReadoutRateCmdValueMap.find(config.readoutRate)->second;
        runCommand("set readout rate", TIM_ID, SPS, readoutRateCmdValue, DON);

        if (config.readoutAmps == ReadoutAmps::Quad) {
            int xSkip = ColBinXSkipMap_Quad.find(config.binFacCol)->second;
            int ySkip = config.binFacRow == 3 ? 1 : 0;
            runCommand("set xy skip for all amps", TIM_ID, SXY, xSkip, ySkip);
        } else {
            int xSkip = ColBinXSkipMap_One.find(config.binFacCol)->second;
            xSkip = std::max(0, xSkip - config.winStartCol);
            runCommand("set xy skip for one amp", TIM_ID, SXY, xSkip, 0);
        }

        runCommand("set image width", TIM_ID, WRM, (Y_MEM | 1), config.getBinnedWidth());

        runCommand("set image height", TIM_ID, WRM, (Y_MEM | 2), config.getBinnedHeight());

        _config = config;
    }

    void Camera::saveImage(double expTime) {
        std::cout << "saveImage(" << expTime << ")\n";
        if (getExposureState().state != StateEnum::ImageRead) {
            throw std::runtime_error("no image available to be read");
        }

        try {
            int deinterlaceAlgorithm = ReadoutAmpsDeinterlaceAlgorithmMap.find(_config.readoutAmps)->second;
            arc::deinterlace::CArcDeinterlace deinterlacer;
            std::cout << "deinterlacer.RunAlg(" << _device.CommonBufferVA() << ", "
                <<  _config.getBinnedHeight() << ", " << _config.getBinnedWidth() << ", " << deinterlaceAlgorithm << ")" << std::endl;
            deinterlacer.RunAlg(_device.CommonBufferVA(), _config.getBinnedHeight(), _config.getBinnedWidth(), deinterlaceAlgorithm);


            arc::fits::CArcFitsFile cFits(_expName.c_str(), _config.getBinnedHeight(), _config.getBinnedWidth());

            // std::string expTypeStr = ExposureTypeNameMap.find(_expType)->second;
            // cFits.WriteKeyword(const_cast<char *>("IMAGETYP"), const_cast<char *>(expTypeStr.c_str()),
            //     arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("exposure type"));

            // if (_expType == ExposureType::Bias) {
            //     expTime = 0;
            //     cFits.WriteKeyword(const_cast<char *>("EXPTIME"), &expTime,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("exposure time (sec)"));
            // } else if (expTime < 0) {
            //     cFits.WriteKeyword(const_cast<char *>("EXPTIME"), &_estExpSec,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("estimated exposure time (sec)"));
            // } else {
            //     cFits.WriteKeyword(const_cast<char *>("EXPTIME"), &expTime,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("measured exposure time (sec)"));
            //     cFits.WriteKeyword(const_cast<char *>("ESTEXPTM"), &_estExpSec,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("estimated exposure time (sec)"));
            // }

            // std::string readoutAmpsStr = ReadoutAmpsNameMap.find(_config.readoutAmps)->second;
            // cFits.WriteKeyword(const_cast<char *>("READAMPS"), const_cast<char *>(readoutAmpsStr.c_str()),
            //     arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("readout amplifier(s)"));

            // std::string readoutRateStr = ReadoutRateNameMap.find(_config.readoutRate)->second;
            // cFits.WriteKeyword(const_cast<char *>("READRATE"), const_cast<char *>(readoutRateStr.c_str()),
            //     arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("readout rate"));

            // cFits.WriteKeyword(const_cast<char *>("CCDBIN1"), &_config.binFacCol,
            //     arc::fits::CArcFitsFile::FITS_INTEGER_KEY, const_cast<char *>("column bin factor"));
            // cFits.WriteKeyword(const_cast<char *>("CCDBIN2"), &_config.binFacRow,
            //     arc::fits::CArcFitsFile::FITS_INTEGER_KEY, const_cast<char *>("row bin factor"));

            // // DATASEC and BIASSEC
            // // for the bias region: use all overscan except the first two columns (closest to the data)
            // // amp names are <x><y> e.g. 11, 12, 21, 22
            // int const prescanWidth = _config.binFacCol == 3 ? 3 : 2;
            // int const prescanHeight = _config.binFacRow == 3 ? 1 : 0;
            // if (_config.getNumAmps() == 4) {
            //     int const overscanWidth  = _config.getBinnedWidth()  - ((2 * prescanWidth) + _config.winWidth); // total, not per amp
            //     int const overscanHeight = _config.getBinnedHeight() - ((2 * prescanHeight) + _config.winHeight);   // total, not per amp

            //     std::string ampListVal{"11 12 21 22"};
            //     cFits.WriteKeyword(const_cast<char *>("AMPLIST"), const_cast<char *>(ampListVal.c_str()),
            //          arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("amplifiers read <x><y> e.g. 12=LR"));

            //     for (auto readoutAmp: ReadoutAmpList) {
            //         auto ampData = AmplifierDataMap.find(readoutAmp)->second;
            //         auto electronicParams = ampData.electronicParamMap.find(_config.readoutRate)->second;
            //         auto const xyName = ampData.getXYName();
            //         bool const isTopHalf   = (ampData.xIndex == 1);
            //         bool const isRightHalf = (ampData.yIndex == 1);

            //         // CSEC is the section of the CCD covered by the data (unbinned)
            //         int const csecWidth  = _config.winWidth  * _config.binFacCol / 2;
            //         int const csecHeight = _config.winHeight * _config.binFacRow / 2;
            //         int const csecStartCol = isRightHalf ? 1 + csecWidth  : 1;
            //         int const csecStartRow = isTopHalf   ? 1 + csecHeight : 1;
            //         int const csecEndCol = csecStartCol + csecWidth  - 1;
            //         int const csecEndRow = csecStartRow + csecHeight - 1;
            //         std::ostringstream csecKeyStream;
            //         csecKeyStream << "CSEC" << xyName;
            //         auto csecKey = csecKeyStream.str();
            //         std::ostringstream csecValStream;
            //         csecValStream << "[" << csecStartCol << ":" << csecEndCol
            //                       << "," << csecStartRow << ":" << csecEndRow << "]";
            //         auto csecVal = csecValStream.str();
            //         cFits.WriteKeyword(const_cast<char *>(csecKey.c_str()), const_cast<char *>(csecVal.c_str()),
            //             arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("data section of CCD (unbinned)"));

            //         // DSEC is the section of the image that is data (binned)
            //         int dsecStartCol = 1 + prescanWidth;
            //         if (isRightHalf) {
            //             dsecStartCol += (_config.winWidth / 2) + overscanWidth;
            //         }
            //         int dsecStartRow = 1 + prescanHeight;
            //         if (isTopHalf) {
            //             dsecStartRow += (_config.winHeight / 2) + overscanHeight;
            //         }
            //         int const dsecEndCol = dsecStartCol + _config.winWidth  - 1;
            //         int const dsecEndRow = dsecStartRow + _config.winHeight - 1;
            //         std::ostringstream dsecKeyStream;
            //         dsecKeyStream << "DSEC" << xyName;
            //         auto dsecKey = dsecKeyStream.str();
            //         std::ostringstream dsecValStream;
            //         dsecValStream << "[" << dsecStartCol << ":" << dsecEndCol
            //                       << "," << dsecStartRow << ":" << dsecEndRow << "]";
            //         auto dsecVal = dsecValStream.str();
            //         cFits.WriteKeyword(const_cast<char *>(dsecKey.c_str()), const_cast<char *>(dsecVal.c_str()),
            //             arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("data section of image (binned)"));

            //         int const biasWidth = (overscanWidth / 2) - 2; // "- 2" to skip first two columns of overscan
            //         int colBiasEnd = _config.getBinnedWidth() / 2;
            //         if (isRightHalf) {
            //             colBiasEnd += biasWidth;
            //         }
            //         int const colBiasStart = 1 + colBiasEnd - biasWidth;
            //         std::ostringstream bsecKeyStream;
            //         bsecKeyStream << "BSEC" << xyName;
            //         auto bsecKey = bsecKeyStream.str();
            //         std::ostringstream bsecValStream;
            //         bsecValStream << "[" << colBiasStart << ":" << colBiasEnd
            //                       << "," << dsecStartRow << ":" << dsecEndRow << "]";
            //         auto bsecVal = bsecValStream.str();
            //         cFits.WriteKeyword(const_cast<char *>(bsecKey.c_str()), const_cast<char *>(bsecVal.c_str()),
            //             arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("bias section of image (binned)"));

            //         std::ostringstream gainKeyStream;
            //         gainKeyStream << "GTGAIN" << xyName;
            //         auto gainKey = gainKeyStream.str();
            //         cFits.WriteKeyword(const_cast<char *>(gainKey.c_str()), &electronicParams.gain,
            //             arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("predicted gain (e-/ADU)"));

            //         std::ostringstream readNoiseKeyStream;
            //         readNoiseKeyStream << "GTRON" << xyName;
            //         auto readNoiseKey = readNoiseKeyStream.str();
            //         cFits.WriteKeyword(const_cast<char *>(readNoiseKey.c_str()), &electronicParams.readNoise,
            //             arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("predicted read noise (e-)"));
            //     }
            // } else if (_config.getNumAmps() == 1) {
            //     int const overscanWidth  = _config.getBinnedWidth()  - (prescanWidth + _config.winWidth);
            //     int const overscanHeight = _config.getBinnedHeight() - (prescanHeight + _config.winHeight);

            //     auto ampData = AmplifierDataMap.find(_config.readoutAmps)->second;
            //     auto electronicParams = ampData.electronicParamMap.find(_config.readoutRate)->second;
            //     auto const xyName = ampData.getXYName();

            //     cFits.WriteKeyword(const_cast<char *>("AMPLIST"), const_cast<char *>(xyName.c_str()),
            //          arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("amplifiers read <x><y> e.g. 12=LR"));

            //     int const csecWidth  = _config.winWidth  * _config.binFacCol;
            //     int const csecHeight = _config.winHeight * _config.binFacRow;
            //     int const csecStartCol = 1 + (_config.winStartCol * _config.binFacCol);
            //     int const csecStartRow = 1 + (_config.winStartRow * _config.binFacRow);
            //     int csecEndCol = csecStartCol + csecWidth  - 1;
            //     int csecEndRow = csecStartRow + csecHeight - 1;
            //     std::ostringstream csecKeyStream;
            //     csecKeyStream << "CSEC" << xyName;
            //     auto csecKey = csecKeyStream.str();
            //     std::ostringstream csecValStream;
            //     csecValStream << "[" << csecStartCol << ":" << csecEndCol
            //                   << "," << csecStartRow << ":" << csecEndRow << "]";
            //     auto csecVal = csecValStream.str();
            //     cFits.WriteKeyword(const_cast<char *>(csecKey.c_str()), const_cast<char *>(csecVal.c_str()),
            //         arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("section in CCD of DSEC (unbinned)"));

            //     int const dsecStartCol = 1 + _config.winStartCol + prescanWidth;
            //     int const dsecStartRow = 1 + _config.winStartRow + prescanHeight;
            //     int const dsecEndCol = dsecStartCol + _config.winWidth  - 1;
            //     int const dsecEndRow = dsecStartRow + _config.winHeight - 1;
            //     std::ostringstream dsecKeyStream;
            //     dsecKeyStream << "DSEC" << xyName;
            //     auto dsecKey = dsecKeyStream.str();
            //     std::ostringstream dsecValStream;
            //     dsecValStream << "[" << dsecStartCol << ":" << dsecEndCol
            //                   << "," << dsecStartRow << ":" << dsecEndRow << "]";
            //     auto dsecVal = dsecValStream.str();
            //     cFits.WriteKeyword(const_cast<char *>(dsecKey.c_str()), const_cast<char *>(dsecVal.c_str()),
            //         arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("data section (binned)"));

            //     int const biasWidth = overscanWidth - 2; // "- 2" to skip first two columns of overscan
            //     int const colBiasEnd = _config.getBinnedWidth();
            //     int const colBiasStart = 1 + colBiasEnd - biasWidth;
            //     std::ostringstream bsecKeyStream;
            //     bsecKeyStream << "BSEC" << xyName;
            //     auto bsecKey = bsecKeyStream.str();
            //     std::ostringstream bsecValStream;
            //     bsecValStream << "[" << colBiasStart << ":" << colBiasEnd
            //                   << "," << dsecStartRow << ":" << dsecEndRow << "]";
            //     auto bsecVal = bsecValStream.str();
            //     cFits.WriteKeyword(const_cast<char *>(bsecKey.c_str()), const_cast<char *>(bsecVal.c_str()),
            //         arc::fits::CArcFitsFile::FITS_STRING_KEY, const_cast<char *>("bias section (binned)"));

            //     std::ostringstream gainKeyStream;
            //     gainKeyStream << "GTGAIN" << xyName;
            //     auto gainKey = gainKeyStream.str();
            //     cFits.WriteKeyword(const_cast<char *>(gainKey.c_str()), &electronicParams.gain,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("predicted gain (e-/ADU)"));

            //     std::ostringstream readNoiseKeyStream;
            //     readNoiseKeyStream << "GTRON" << xyName;
            //     auto readNoiseKey = readNoiseKeyStream.str();
            //     cFits.WriteKeyword(const_cast<char *>(readNoiseKey.c_str()), &electronicParams.readNoise,
            //         arc::fits::CArcFitsFile::FITS_DOUBLE_KEY, const_cast<char *>("predicted read noise (e-)"));
            // } else {
            //     std::cout << "Warning: numAmps=" << _config.getNumAmps() << " != 1 or 4; cannot write DATASEC and BIASSEC" << std::endl;
            // }

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
        _assertIdle();
        runCommand("open shutter", TIM_ID, OSH);
    }

    void Camera::closeShutter() {
        _assertIdle();
        runCommand("close shutter", TIM_ID, CSH);
    }

// private methods

    void Camera::_assertIdle() {
        if (this->isBusy()) {
            throw std::runtime_error("busy");
        }
    }

    void Camera::_clearBuffer() {
        std::cout << "_device.FillCommonBuffer(0)\n";
        _device.FillCommonBuffer(0);
        _bufferCleared = true;
    }

    double Camera::_estimateReadTime(int nPix) const {
        return nPix / ReadoutRateFreqMap.find(_config.readoutRate)->second;
    }

    void Camera::_setIdle() {
        _cmdExpSec = -1;
        _estExpSec = -1;
        _segmentExpSec = -1;
        _segmentStartValid = false;
        _clearBuffer();
    }

    void Camera::runCommand(std::string const &descr, int boardID, int cmd, int arg1, int arg2, int arg3) {
        if ((boardID != TIM_ID) && (boardID != UTIL_ID) && (boardID != PCI_ID)) {
            std::ostringstream os;
            os << std::hex << "unknown boardID=0x" << boardID;
            throw std::runtime_error(os.str());
        }
        std::cout << std::hex << "_device.Command("
            <<  "0x" << boardID
            << ", " << formatCmd(cmd)
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
