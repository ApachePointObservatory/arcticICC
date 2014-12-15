#pragma once

#include <chrono>
#include <string>

#include "CArcDevice/CArcPCIe.h"
#include "CArcDevice/CArcDevice.h"

#include "arcticICC/basics.h"

namespace arcticICC {

    static int const CCDWidth = 4096;   // width of CCD (unbinned pixels)
    static int const CCDHeight = 4096;  // width of CCD (unbinned pixels)
    static int const XExtraPix = 104;   // total x prescan + overscan pixels for all amplifiers combined (unbinned pixels)
    static int const YExtraPix = 8;     // total y overscan (y prescan=0) for all amplifiers combined
    static int const MaxBinFactor = 4;  // maximum allowed bin factor
    /// map of x bin factor: x prescan pixels (defined as all pixels to discard before good data);
    /// the distinction only matters for 3x binning, where the 4th pixel is a mix of prescan and data
    #ifndef SWIG
    static std::map<int, int> XBinPrescanMap { // bin factor: x prescan (pixels to discard before good data)
        {1, 6}, {2, 4}, {3, 4}, {4, 3}
    };
    static int const OneAmpOverscan = XExtraPix - XBinPrescanMap.find(1)->second; // 98
    #endif

    class CameraConfig {
    public:
        /**
        Construct a CameraConfig with default values
        */
        explicit CameraConfig();

        /**
        Throw std::runtime_error if the configuration is not valid
        */
        void assertValid() const;

        /**
        Return true if readoutAmps is compatible with sub-windowing
        */
        bool canWindow() const { return (readoutAmps == ReadoutAmps::LL) || (readoutAmps == ReadoutAmps::LR)
            || (readoutAmps == ReadoutAmps::UL) || (readoutAmps == ReadoutAmps::UR); }

        /**
        Set configuration for full windowing
        */
        void setFullWindow() {
            winRowStart = 0;
            winColStart = 0;
            winWidth == CCDWidth / colBinFac;
            winHeight == CCDHeight / rowBinFac;
        }

        /**
        Return image width (including overscan), in unbinned pixels
        */
        int getUnbinnedWidth() const { return getBinnedWidth() * colBinFac; }

        /**
        Return image height (including overscan), in unbinned pixels
        */
        int getUnbinnedHeight() const { return getBinnedHeight() * rowBinFac; }

        /**
        Return image width (including overscan), in binned pixels
        */
        int getBinnedWidth() const { return winWidth + (XExtraPix / colBinFac); }

        /**
        Return image height (including overscan), in binned pixels
        */
        int getBinnedHeight() const { return winHeight + (isFullWindow() ? (YExtraPix / rowBinFac) : 0); }

        /**
        Return true if configured for full windowing
        */
        bool isFullWindow() const { return (winRowStart == 0) && (winColStart == 0)
            && (winWidth >= CCDWidth / colBinFac) && (winHeight >= CCDHeight / rowBinFac); }

        ReadoutAmps readoutAmps;    /// readout amplifiers
        ReadoutRate readoutRate;    /// readout rate
        int colBinFac;     /// column bin factor; must be in range 1-MaxBinFactor
        int rowBinFac;     /// row bin factor; must be in range 1-MaxBinFactor
        int winColStart;   /// starting column for data subwindow (binned pixels, starting from 0)
        int winRowStart;   /// starting row for data subwindow (binned pixels, starting from 0)
        int winWidth;      /// window width (binned pixels)
        int winHeight;     /// window height (binned pixels)
    };

    /**
    ARCTIC imager CCD

    This is a thin wrapper around the Leach API; it adds the "Resource Acquisition Is Initialization"
    pattern and simplifies some call signatures.

    @warning while exposing you must poll getExposureState often enough that you call it at least once
    while the camera is being read out. This assures correct detection that an image is ready.
    */
    class Camera {
    public:
        /**
        Contruct a camera: open the camera and allocate all resources

        Note that the Leach controller does not support y overscan.
        */
        explicit Camera();

        /**
        Destructor: release all allocated resources
        */
        ~Camera();

        /**
        Return true if not idle (i.e. if exposing, paused exposure, or reading out)
        */
        bool isBusy() { return getExposureState().isBusy(); }

        /**
        Start an exposure

        @param[in] expTime  exposure time in seconds
        @param[in] expType  exposure type
        @param[in] expName  name of exposure FITS file
        @throw std::runtime_error if an exposure is in progress
        @throw std::runtime_error if expType is ExposureType::Bias and expTime > 0
        */
        void startExposure(double expTime, ExposureType expType, std::string const &expName);

        /**
        Pause an exposure, closing the shutter if it was open

        @throw std::runtime_error if no exposure is paused
        */
        void pauseExposure();

        /**
        Resume a paused exposure, opening the shutter if that's how the exposure was started

        @throw std::runtime_error if no exposure is paused
        */
        void resumeExposure();

        /**
        Abort an exposure or readout, discarding the data

        @throw std::runtime_error if there is no exopsure to abort
        */
        void abortExposure();

        /**
        Stop an exposure, saving the data

        @throw std::runtime_error if there is no exopsure to stop
        */
        void stopExposure();

        /**
        Get current exposure state
        */
        ExposureState getExposureState();

        /**
        Get the camera configuration
        */
        CameraConfig getConfig() const { return _config; }

        /**
        Set the camera configuration

        @param[in] configuration  new configuration

        @throw std::runtime_error if new configuration not valid or if camera is not idle
        */
        void setConfig(CameraConfig const &cameraConfig);

        /**
        Save image to a FITS file

        @param[in] expTime  exposure time (sec); if <0 then the internal timer is used.
            If you have feedback from the shutter then you can provide a better value than the internal timer.

        @throw std::runtime_error if no image is available to be saved
        */
        void saveImage(double expTime=-1);

        /**
        Open the shutter

        @throw std::runtime_error if an exposure is in progress
        */
        void openShutter();

        /**
        Close the shutter

        @throw std::runtime_error if an exposure is in progress
        */
        void closeShutter();

    private:
        void assertIdle();  /// assert that the camera is not busy
        void _setIdle();    /// set values indicating idle state (_cmdExpSec, _fullReadTime and _isPaused)
        void _clearBuffer();    /// clear image buffer and set _bufferCleared
        double _readTime(int nPix) const; /// estimate readout time (sec) based on number of pixels to read
        /**
        Run one command, as described in the Leach document Controller Command Description
        @param[in] boardID  controller board code: one of TIM_ID, PCI_ID or UTIL_ID
        @param[in] cmd  command code
        @param[in] arg1  argument 1 (optional)
        @param[in] arg2  argument 2 (optional)
        @param[in] arg3  argument 3 (optional)
        */
        void runCommand(std::string const &descr, int boardID, int cmd, int arg1=0, int arg2=0, int arg3=0);
        // it might be better to read the following parameters directly from the controller,
        // but they cannot safely be read while the controller is reading out an image
        /**
        Set number of rows to skip, based on readout amps and bin factor
        */
        CameraConfig _config;   /// camera configuration
        std::string _expName;       /// exposure name (used for the FITS file)
        ExposureType _expType;      /// exposure type
        double _cmdExpSec;          /// commanded exposure time, in seconds; <0 if idle
        double _segmentExpSec;      /// exposure time for this segment; this starts at the requested exposur time
            /// and is decreased each time the exposure is paused
        std::chrono::steady_clock::time_point _segmentStartTime;   /// start time of this exposure segment;
            /// updated when an exposure is paused or resumed; invalid if isExposing false
        bool _segmentStartValid;    /// true if exposing, reading out or read out, but not paused or idle
        bool _bufferCleared;        /// true when idle or exposing; getExposureStatus sets it when reading out

        arc::device::CArcPCIe _device;  /// the Leach API's representation of a camera controller
    };

    std::ostream &operator<<(std::ostream &os, CameraConfig const &config);

} // namespace
