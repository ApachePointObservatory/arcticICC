#pragma once

#include <array>
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

    /**
    ARCTIC imager CCD

    This is a thin wrapper around the Leach API; it adds the "Resource Acquisition Is Initialization"
    pattern and simplifies some call signatures.
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
        Return true if the current readout amps is compatible with sub-windowing
        */
        bool canWindow() { return canWindow(_readoutAmps); }

        /**
        Return true if the specified readout amps is compatible with sub-windowing
        */
        bool canWindow(ReadoutAmps readoutAmps) { return (readoutAmps == ReadoutAmps::LL) || (readoutAmps == ReadoutAmps::LR)
            || (readoutAmps == ReadoutAmps::UL) || (readoutAmps != ReadoutAmps::UR); }

        /**
        Get current exposure state
        */
        ExposureState getExposureState();

        /**
        Get bin factor

        @return bin factor in x (cols), y (rows)
        */
        std::array<int, 2> getBinFactor() const { return std::array<int, 2>{_colBinFac, _rowBinFac}; };

        /**
        Set bin factor

        @param[in] colBinFac: number of columns per bin (1, 2, 3 or 4)
        @param[in] rowBinFac: number of rows per bin (1, 2, 3 or 4)

        The resulting number of binned columns = window width (unbinned) / colBinFac
        using truncated integer division. Similarly for rows.

        @throw std::runtime_error if:
        - colBinFac or rowBinFac < 1 or > 4
        - an exposure is in progress
        */
        void setBinFactor(int colBinFac, int rowBinFac);

        /**
        Get the image window

        @return window colStart, rowStart, width, height, all in unbinned pixels
        */
        std::array<int, 4> getWindow() const {
            return std::array<int, 4> {_winRowStart, _winColStart, _winWidth, _winHeight};
        };

        /**
        Return true if configured for full windowing
        */
        bool isFullWindow() const { return (_winRowStart == 0) && (_winColStart == 0)
            && (_winWidth == CCDWidth) && (_winHeight == CCDHeight); }

        /**
        Set window to use full CCD
        */
        void setFullWindow();

        /**
        Set image window

        @param[in] colStart: start column (unbinned pixels; 0 is the first column)
        @param[in] rowStart: start row (unbinned pixels; 0 is the first row)
        @param[in] width: number of columns in the data (unbinned pixels)
        @param[in] height: number of rows in the data (unbinned pixels)

        @note the binned image size is width/colBinFac, height/rowBinFac, using truncated integer division

        @throw std::runtime_error if the requested image extends off the imaging area
        @throw std::runtime_error if readoutAmps is not a single amplifier
        */
        void setWindow(int colStart, int rowStart, int width, int height);

        /**
        Get the amplifiers being read out
        */
        ReadoutAmps getReadoutAmps() const { return _readoutAmps; }

        /**
        Set the ampifiers being read out

        @param[in] readoutAmps ampifiers used to read out the CCD

        @throw std::runtime_error if not idle
        */
        void setReadoutAmps(ReadoutAmps readoutAmps);

        /**
        Get the readout rate
        */
        ReadoutRate getReadoutRate() const { return _readoutRate; }

        /**
        Set the readout rate

        @param[in] readoutRate readout rate

        @throw std::runtime_error if not idle
        */
        void setReadoutRate(ReadoutRate readoutRate);

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

        /**
        Return image width, in unbinned pixels (includes overscan)
        */
        int getUnbinnedWidth() const { return _winWidth + XExtraPix; }

        /**
        Return image height, in unbinned pixels (will include overscan, if y overscan is ever supported)
        */
        int getUnbinnedHeight() const { return _winHeight + YExtraPix; }

        /**
        Return image width, in binned pixels (includes overscan)
        */
        int getBinnedWidth() const { return getUnbinnedWidth() / _colBinFac; }

        /**
        Return image height, in binned pixels (will include overscan, if y overscan is ever supported)
        */
        int getBinnedHeight() const { return getUnbinnedHeight() / _rowBinFac; }

    private:
        void assertIdle();  /// assert that the camera is not busy
        void _setIdle();    /// set values indicating idle state (_cmdExpSec, _fullReadTime and _isPaused)
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
        ReadoutAmps _readoutAmps;
        ReadoutRate _readoutRate;
        int _colBinFac;     /// column bin factor
        int _rowBinFac;     /// row bin factor
        int _winColStart;   /// starting column for data subwindow (unbinned pixels, starting from 0)
        int _winRowStart;   /// starting row for data subwindow (unbinned pixels, starting from 0)
        int _winWidth;      /// window width (unbinned pixels)
        int _winHeight;     /// window height (unbinned pixels)
        std::string _expName;       /// exposure name (used for the FITS file)
        ExposureType _expType;      /// exposure type
        double _cmdExpSec;          /// commanded exposure time, in seconds; <0 if idle
        double _segmentExpSec;      /// exposure time for this segment; this starts at the requested exposur time
            /// and is decreased each time the exposure is paused
        std::chrono::steady_clock::time_point _segmentStartTime;   /// start time of this exposure segment;
            /// updated when an exposure is paused or resumed; invalid if isExposing false
        bool _segmentStartValid;    /// true if exposing, reading out or read out, but not paused or idle

        arc::device::CArcPCIe _device;  /// the Leach API's representation of a camera controller
    };

} // namespace
