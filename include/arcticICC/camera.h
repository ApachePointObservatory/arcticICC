#pragma once

#include <string>
#include <vector>
#include <array>

namespace arctic {

enum class ExposureState {
    Idle,
    Exposing,
    Paused,
    Reading,
}

enum class ReadRate {
    Slow,
    Medium,
    Fast,
}

/**
ARCTIC imager CCD

This is a thin wrapper around the Leach API which attempts to add the "Resource Acquisition
Is Initialization" pattern and simplify some call signatures.
*/
class Camera: {
public:
    /**
    Contruct a camera: open the camera and allocate all resources

    @param[in] dataWidth: height of data region of CCD (pixels)
    @param[in] dataHeight: width of data region of CCD (pixels)
    @param[in] xOverscan  overscan in x (pixels)

    Note that the Leach controller does not support y overscan.
    */
    Camera(int dataWidth, int dataHeight, int xOverscan);

    /**
    Destructor: release all allocated resources
    */
    ~Camera();

    /**
    Start an exposure

    @param[in] expTime: exposure time in seconds
    @param[in] openShutter: if true then open the shutter during the exposure
    @raise std::runtime_error if an exposure is in progress
    */
    void startExposure(float expTime, bool openShutter=true);

    /**
    Pause an exposure, closing the shutter if it was open

    @raise std::runtime_error if no exposure is paused
    */
    void pauseExposure();

    /**
    Resume a paused exposure, opening the shutter if that's how the exposure was started

    @raise std::runtime_error if no exposure is paused
    */
    void resumeExposure();

    /**
    Abort an exposure, discarding the data. A no-op if there is no exposure.

    @return true if there was an exposure to abort, else false
    */
    bool abortExposure();

    /**
    Get current exposure state
    */
    ExposureState getExposureState() const;

    /**
    Return true if not idle
    */
    bool isBusy() const { return this->getExposureState() != ExposureState::Idle; };

    /**
    Get remaining exposure time, or 0 if not exposing (sec)
    */
    float getExposureTime() const;

    /**
    Get bin factor

    @return bin factor in x (cols), y (rows)
    */
    std::array<int, 2> getBinFactor() const { return std::array<int, 2>{_colBinFac, _rowBinFac}; };

    /**
    Set bin factor

    @param[in] colBinFac: number of columns per bin
    @param[in] rowBinFac: number of rows per bin

    The resulting number of binned columns = window width (unbinned) / colBinFac
    using truncated integer division. Similarly for rows.

    @raise std::runtime_error if:
    - colBinFac or rowBinFac < 1 or > unbinned image size
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
    Set image window

    @param[in] colStart: start column (unbinned pixels; 0 is the first column)
    @param[in] rowStart: start row (unbinned pixels; 0 is the first row)
    @param[in] width: number of columns in the data (unbinned pixels)
    @param[in] height: number of rows in the data (unbinned pixels)

    @note you may specify 0,0,0,0 to specify the full frame
    @note the binned image size is width/colBinFac, height/rowBinFac, using truncated integer division

    @raise std::runtime_error if the requested image extends off the imaging area
    */
    void setWindow(int colStart, rowStart, int width, int height);

    /**
    Get the readout rate
    */
    ReadRate getReadRate() const;

    /**
    Set the readout rate
    */
    void setReadRate(ReadRate readRate);

    /**
    Open the shutter

    @raise std::runtime_error if an exposure is in progress
    */
    void openShutter();

    /**
    Close the shutter

    @raise std::runtime_error if an exposure is in progress
    */
    void closeShutter();

    int const dataWidth;    // width of full data region of CCD (unbinned pixels)
    int const dataHeight;   // height of full data region of CCD (unbinned pixels)
    int const xOverscan;    // x overscan (unbinned pixels)

private:
    void assertIdle();
    void runCommand(std::string const &descr, int arg0=0, int arg1=0, int arg2=0, int arg3=0);
    // it would be safer to read the following parameters directly from the controller,
    // but I don't know how to do that
    int _colBinFac;     // column bin factor
    int _rowBinFac;     // row bin factor
    int _winColStart;   // starting column for data subwindow (unbinned pixels, starting from 0)
    int _winRowStart;   // starting row for data subwindow (unbinned pixels, starting from 0)
    int _winWidth;      // window width (unbinned pixels)
    int _winHeight;     // window height (unbinned pixels)

    CArcPCIe  _device;  // the Leach API's representation of a camera controller
};


/**
Get a list of device names
*/
std::vector<std::string> getDevNameList(std::string const &devDir);

} // namespace