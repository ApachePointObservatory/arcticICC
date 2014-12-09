#pragma once

#include <string>
#include <map>
#include <unordered_set>

namespace arcticICC {

enum class StateEnum {
    Idle,
    Exposing,
    Paused,     // exposure paused
    Reading,    // reading out an exposure
    ImageRead   // an image has been read and not saved
};

const static std::map<StateEnum, std::string> StateNameMap = {
    {StateEnum::Idle,      "Idle"},
    {StateEnum::Exposing,  "Exposing"},
    {StateEnum::Paused,    "Paused"},
    {StateEnum::Reading,   "Reading"},
    {StateEnum::ImageRead, "ImageRead"}
};

enum class ReadoutAmps {
    LL,
    LR,
    UR,
    UL,
    All,
};

/// map of ReadoutAmps enum: string representation
const static std::map<ReadoutAmps, std::string> ReadoutAmpsNameMap {
    {ReadoutAmps::LL,   "LL"},
    {ReadoutAmps::LR,   "LR"},
    {ReadoutAmps::UR,   "UR"},
    {ReadoutAmps::UL,   "UL"},
    {ReadoutAmps::All,  "All"}
};

enum class ReadoutRate {
    Slow,
    Medium,
    Fast
};

/// map of ReadoutRate enum: string representation
const static std::map<ReadoutRate, std::string> ReadoutRateNameMap {
    {ReadoutRate::Slow,   "Slow"},
    {ReadoutRate::Medium, "Medium"},
    {ReadoutRate::Fast,   "Fast"}
};

/// map of ReadoutRate enum: approximate pixel raad frequency (Hz)
const static std::map<ReadoutRate, double> ReadoutRateFreqMap {
    {ReadoutRate::Slow,   150e3},
    {ReadoutRate::Medium, 450e3},
    {ReadoutRate::Fast,   900e3}
};

/// list closed-shutter exposures first, with Dark being the last of those
enum class ExposureType {
    Bias,
    Dark,
    Flat,
    Object,
};

/// map of ExposureType enum: string representation
const static std::map<ExposureType, std::string> ExposureTypeNameMap {
    {ExposureType::Bias,   "Bias"},
    {ExposureType::Dark,   "Dark"},
    {ExposureType::Flat,   "Flat"},
    {ExposureType::Object, "Object"}
};


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
    bool isBusy() const { return (state == StateEnum::Exposing) || (state == StateEnum::Paused) || (state == StateEnum::Reading); }
};

} // namespace