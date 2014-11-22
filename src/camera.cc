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

namespace arctic {

    Camera::Camera(int dataWidth, int dataHeight, int xOverscan, int yOverscan) :
        dataWidth(dataWidth), dataHeight(dataHeight), xOverscan(xOverscan),
        _colBinFac(1), _rowBinFac(1),
        _winColStart(0), _winRowStart(0), _winWidth(dataWidth), _winHeight(dataHeight),
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
    }

    ~Camera::Camera() {
        _device.Close();
    }

    /**
    Start an exposure

    @param[in] expTime: exposure time in seconds. Note that the internal timer resolution is 1 ms.
    @param[in] openShutter: if true then open the shutter during the exposure
    @raise std::runtime_error if an exposure is in progress
    */
    void startExposure(float expTime, bool openShutter=true) {
        assertIdle();
        if (expTime < 0) {
            std::ostringstream os;
            os << "exposure time=" << expTime << " must be non-negative";
            throw std::runtime_error(os.str())
        }

        _device.SetOpenShutter(openShutter);

        int expTimeMS = int(expTime*1000.0);
        std::ostringstream os;
        os << "Set exposure time to " << expTimeMS << " ms" << expTimeRetVal;
        runCommand(os.str(), TIM_ID, SET, expTimeMS);

        runCommand("start exposure", TIM_ID, SEX);
    }

    /**
    Pause an exposure, closing the shutter if it was open

    @raise std::runtime_error if no exposure is paused
    */
    void Camera::pauseExposure();

    /**
    Resume a paused exposure, opening the shutter if that's how the exposure was started

    @raise std::runtime_error if no exposure is paused
    */
    void Camera::resumeExposure();

    /**
    Abort the current exposure or readout, discarding the data. A no-op if there is no exposure.

    @return true if there was an exposure to abort, else false
    */
    bool Camera::abortExposure() {
        if (!isBusy()) {
            return false;
        }
        _device.StopExposure()
        return true;
    }

    /**
    Get current exposure state
    */
    ExposureState Camera::getExposureState() const {
        if _device.IsReadout() {
            return ExposureState::Reading;
        }
    }

    /**
    Get remaining exposure time, or 0 if not exposing (sec)
    */
    float Camera::getExposureTime() const;

    void Camera::setBinFactor(int colBinFac, int rowBinFac) {
        assertIdle();
        if (colBinFac < 1 or colBinFac > dataWidth) {
            os << "colBinFac=" << colBinFac << " < 1 or > " << dataWidth;
            throw std::runtime_error
        }
        if (rowBinFac < 1 or rowBinFac > dataHeight) {
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
            os << "colStart=" << colStart << " < 0 or >= " << dataWidth;
            throw std::runtime_error
        }
        if (rowStart < 0 || rowStart >= dataHeight) {
            os << "rowStart=" << rowStart << " < 0 or >= " << dataHeight;
            throw std::runtime_error
        }
        if (width < 1 or width > dataWidth) {
            os << "width=" << width << " < 1 or > " << dataWidth;
            throw std::runtime_error
        }
        if (height < 1 or height > dataHeight) {
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

    /**
    Get the readout rate
    */
    ReadRate Camera::getReadRate() const;

    /**
    Set the readout rate
    */
    void Camera::setReadRate(ReadRate readRate);

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

    void Camera::runCommand(std::string const &descr, int arg0=0, int arg1=0, int arg2=0, int arg3=0) {
        int retVal = _device.Command(arg0, arg1, arg2, arg3);
        if (retVal != DON) {
            std::ostringstream os;
            os << descr << " failed with retVal=" << retVal;
            throw std::runtime_error(os.str());
        }
    }
} // namespace