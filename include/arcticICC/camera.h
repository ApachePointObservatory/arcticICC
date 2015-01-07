#pragma once

#include <chrono>
#include <string>
#include <map>

#include "CArcDevice/CArcPCIe.h"
#include "CArcDevice/CArcDevice.h"

#include "arcticICC/basics.h"

namespace arcticICC {

    static int const CCDWidth = 4096;   // width of CCD (unbinned pixels)
    static int const CCDHeight = 4096;  // width of CCD (unbinned pixels)
    static int const XOverscan = 102;   // desired width of x overscan region, unbinned pixels
        // if using quad readout then each amplifier gets half of this
        // the actual overscan region is further reduced by any prescan (2 binned pixels per amp, in our case)
    static int const MaxBinFactor = 4;  // maximum allowed bin factor

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
        bool canWindow() const { return (getNumAmps() == 1); }

        /**
        Return the number of amplifiers being read out
        */
        int getNumAmps() const { return ReadoutAmpsNumAmpsMap.find(readoutAmps)->second; }

        /**
        Set configuration for full windowing
        */
        void setFullWindow() {
            winStartCol = 0;
            winStartRow = 0;
            winWidth = computeBinnedWidth(CCDWidth);
            winHeight = computeBinnedHeight(CCDHeight);
        };

        /**
        Return image width (including prescan and overscan), in unbinned pixels
        */
        int getUnbinnedWidth() const { return getBinnedWidth() * binFacCol; }

        /**
        Return image height (including prescan and overscan) in unbinned pixels
        */
        int getUnbinnedHeight() const { return getBinnedHeight() * binFacRow; }

        /**
        Return image width (including prescan and overscan) in binned pixels
        */
        int getBinnedWidth() const;

        /**
        Return image height (including prescan and overscan) in binned pixels
        */
        int getBinnedHeight() const;

        /**
        Return true if configured for full windowing
        */
        bool isFullWindow() const { return (winStartRow == 0) && (winStartCol == 0)
            && (winWidth >= computeBinnedWidth(CCDWidth)) && (winHeight >= computeBinnedHeight(CCDHeight)); }

        ReadoutAmps readoutAmps;    /// readout amplifiers
        ReadoutRate readoutRate;    /// readout rate
        int binFacCol;     /// column bin factor; must be in range 1-MaxBinFactor
        int binFacRow;     /// row bin factor; must be in range 1-MaxBinFactor
        int winStartCol;   /// starting column for data subwindow (binned pixels, starting from 0)
        int winStartRow;   /// starting row for data subwindow (binned pixels, starting from 0)
        int winWidth;      /// window width (binned pixels)
        int winHeight;     /// window height (binned pixels)

        static int getMaxWidth(); /// get maximum image width (unbinned pixels)
        static int getMaxHeight(); /// get maximum image height (unbinned pixels)

        /**
        Compute a binned width

        The value is even for both amplifiers, even if only using single readout,
        just to keep the system more predictable. The result is that the full image size
        is the same for 3x3 binning regardless of whether you read one amp or four,
        and as a result you lose one row and one column when you read one amp.
        */
        int computeBinnedWidth(int unbWidth) const { return (unbWidth / (2 * binFacCol)) * 2; }
        /**
        Compute a binned height

        See notes for computeBinnedHeight
        */
        int computeBinnedHeight(int unbHeight) const { return (unbHeight / (2 * binFacRow)) * 2; }
    };

    /**
    Amplifier electronic parameters, especially those affected by readout rate
    */
    class AmplifierElectronicParameters {
    public:
        double gain;        /// predicted gain (e-/DN)
        double readNoise;   /// predicted readout noise (e-)
    };

    class AmplifierData {
    public:
        int xIndex;
        int yIndex;
        std::map<ReadoutRate, AmplifierElectronicParameters> electronicParamMap;

        /**
        Get amplifier name as <xIndex+1><yIndex+1>
        */
        std::string getXYName() const {
            std::ostringstream os;
            os << xIndex + 1 << yIndex + 1;
            return os.str();
        }
    };

    #ifndef SWIG
    const std::map<ReadoutAmps, AmplifierData> AmplifierDataMap = {
        {ReadoutAmps::LL, {0, 0, {
            {ReadoutRate::Fast,     {6.6, 1.98}},
            {ReadoutRate::Medium,   {4.5, 1.99}},
            {ReadoutRate::Slow,     {4.0, 1.43}}
        }}},
        {ReadoutAmps::LR, {1, 0, {
            {ReadoutRate::Fast,     {6.4, 1.97}},
            {ReadoutRate::Medium,   {4.3, 1.97}},
            {ReadoutRate::Slow,     {3.7, 1.42}}
        }}},
        {ReadoutAmps::UL, {0, 1, {
            {ReadoutRate::Fast,     {6.4, 2.01}},
            {ReadoutRate::Medium,   {4.6, 2.03}},
            {ReadoutRate::Slow,     {3.8, 1.43}}
        }}},
        {ReadoutAmps::UR, {1, 1, {
            {ReadoutRate::Fast,     {6.5, 1.99}},
            {ReadoutRate::Medium,   {4.4, 1.98}},
            {ReadoutRate::Slow,     {3.7, 1.41}}
        }}}
    };
    #endif

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

        @warning if this fails then the camera is in an unknown and possibly invalid state.
        If this occurs then you should retry the command or reset the camera.
        */
        void setConfig(CameraConfig const &cameraConfig);

        /**
        Save image to a FITS file

        @param[in] expTime  exposure time (sec); if <0 then the internal timer is used.
            If taking a bias then expTime is ignored; the reported exposure time is 0;
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
        void _assertIdle();  /// assert that the camera is not busy
        void _clearBuffer();    /// clear image buffer and set _bufferCleared
        double _estimateReadTime(int nPix) const; /// estimate readout time (sec) based on number of pixels to read
        void _setIdle();    /// set values indicating idle state (_cmdExpSec, _fullReadTime and _isPaused)
        /**
        Run one command, as described in the Leach document Controller Command Description
        @param[in] boardID  controller board code: one of TIM_ID, PCI_ID or UTIL_ID
        @param[in] cmd  command code
        @param[in] arg1  argument 1 (optional)
        @param[in] arg2  argument 2 (optional)
        @param[in] arg3  argument 3 (optional)
        */
        void runCommand(std::string const &descr, int boardID, int cmd, int arg1=0, int arg2=0, int arg3=0);
        CameraConfig _config;       /// camera configuration
        std::string _expName;       /// exposure name (used for the FITS file)
        ExposureType _expType;      /// exposure type
        double _cmdExpSec;          /// commanded exposure time, in seconds; <0 if idle
        double _estExpSec;          /// estimated actuall exposure time, in seconds;
            /// set to -1 until the exposure ends (either prematurely via stop or normally as detected by getStatus)
        double _segmentExpSec;      /// exposure time for this segment; this starts at the requested exposure time
            /// and is decreased each time the exposure is paused
        std::chrono::steady_clock::time_point _segmentStartTime;   /// start time of this exposure segment;
            /// updated when an exposure is paused or resumed; invalid if isExposing false
        bool _segmentStartValid;    /// true if exposing, reading out or read out, but not paused or idle
        bool _bufferCleared;        /// true when idle or exposing; getExposureStatus sets it when reading out

        arc::device::CArcPCIe _device;  /// the Leach API's representation of a camera controller
    };

    std::ostream &operator<<(std::ostream &os, CameraConfig const &config);

} // namespace
