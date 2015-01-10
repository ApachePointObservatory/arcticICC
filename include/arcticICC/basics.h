#pragma once

#include <string>
#include <map>

namespace arcticICC {

enum class StateEnum {
    Idle,
    Exposing,
    Paused,     // exposure paused
    Reading,    // reading out an exposure
    ImageRead   // an image has been read and not saved
};

#ifndef SWIG
const static std::map<StateEnum, std::string> StateNameMap {
    {StateEnum::Idle,      "Idle"},
    {StateEnum::Exposing,  "Exposing"},
    {StateEnum::Paused,    "Paused"},
    {StateEnum::Reading,   "Reading"},
    {StateEnum::ImageRead, "ImageRead"}
};
#endif

enum class ReadoutAmps {
    LL,
    LR,
    UR,
    UL,
    Quad,
};

#ifndef SWIG
/// map of ReadoutAmps enum: string representation
const static std::map<ReadoutAmps, std::string> ReadoutAmpsNameMap {
    {ReadoutAmps::LL,   "LL"},
    {ReadoutAmps::LR,   "LR"},
    {ReadoutAmps::UR,   "UR"},
    {ReadoutAmps::UL,   "UL"},
    {ReadoutAmps::Quad, "Quad"}
};

std::map<arcticICC::ReadoutAmps, int> ReadoutAmpsNumAmpsMap {
    {arcticICC::ReadoutAmps::LL,    1},
    {arcticICC::ReadoutAmps::LR,    1},
    {arcticICC::ReadoutAmps::UR,    1},
    {arcticICC::ReadoutAmps::UL,    1},
    {arcticICC::ReadoutAmps::Quad,  4},
};
#endif

enum class ReadoutRate {
    Slow,
    Medium,
    Fast
};

#ifndef SWIG
/// map of ReadoutRate enum: string representation
const static std::map<ReadoutRate, std::string> ReadoutRateNameMap {
    {ReadoutRate::Slow,   "Slow"},
    {ReadoutRate::Medium, "Medium"},
    {ReadoutRate::Fast,   "Fast"}
};

/// map of ReadoutRate enum: approximate pixel raad frequency (Hz)
/// 900e3, etc. is from Joseph Heunerhof
/// 
const static std::map<ReadoutRate, double> ReadoutRateFreqMap {
    // from Joseph Heunerhof:
    // {ReadoutRate::Fast,   900e3}
    // {ReadoutRate::Medium, 450e3},
    // {ReadoutRate::Slow,   150e3},
    // from Bob Leach's final report: read times were: 6.6, 20.0 and 41.7 seconds for full CCD in quad mode,
    // binned 2x2 and probably a total of 50 pixels X prescan + overscan and negligible Y prescan + overscan
    // (hence 4296704 = 2048 * 2098 pixels)
    {ReadoutRate::Fast,   651015.8},
    {ReadoutRate::Medium, 214835.2},
    {ReadoutRate::Slow,   103038.5},
};
#endif

/// list closed-shutter exposures first, with Dark being the last of those
enum class ExposureType {
    Bias,
    Dark,
    Flat,
    Object,
};

#ifndef SWIG
/// map of ExposureType enum: string representation
const static std::map<ExposureType, std::string> ExposureTypeNameMap {
    {ExposureType::Bias,   "Bias"},
    {ExposureType::Dark,   "Dark"},
    {ExposureType::Flat,   "Flat"},
    {ExposureType::Object, "Object"}
};
#endif

/**
Exposure state, as returned by Camera::getExposureState
*/
class ExposureState {
public:
    /**
    Construct an ExposureState

    @param[in] state  state
    @param[in] fullTime  full duration for this state (sec)
    @param[in] remTime  remaining duration for this state (sec)
    */
    explicit ExposureState(StateEnum state=StateEnum::Idle, double fullTime=0, double remTime=0)
    : state(state), fullTime(fullTime), remTime(remTime) {}
    StateEnum state;    ///< state
    double fullTime;    ///< full duration for this state (sec)
    double remTime;     ///< remaining duration for this state (sec)
    /**
    Return true if camera is busy (exposing, paused or reading)
    */
    bool isBusy() const {
        return (state == StateEnum::Exposing) || (state == StateEnum::Paused) || (state == StateEnum::Reading);
    }
};

} // namespace arcticICC
