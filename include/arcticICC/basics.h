#pragma once

#include <string>
#include <map>
#include <unordered_set>

namespace arctic {

enum class StateEnum {
    Idle,
    Exposing,
    Paused,     // exposure paused
    Reading,    // reading out an exposure
    ImageRead   // an image has been read and not saved
};

const static std::map<StateEnum, std::string> StateMap = {
    {StateEnum::Idle,      "Idle"},
    {StateEnum::Exposing,  "Exposing"},
    {StateEnum::Paused,    "Paused"},
    {StateEnum::Reading,   "Reading"},
    {StateEnum::ImageRead, "ImageRead"}
}

std::unordered_set<StateEnum> BusyEnumSet = {
    StateEnum::Exposing,
    StateEnum::Paused,
    StateEnum::Reading
}

enum class ReadoutRate {
    Slow,
    Medium,
    Fast
};

const static std::map<ReadoutRate, std::string> ReadoutRateMap {
    {ReadoutRate::Slow,   "Slow"},
    {ReadoutRate::Medium, "Medium"},
    {ReadoutRate::Fast,   "Fast"}
};


// list closed-shutter exposures first, with Dark being the last of those
enum class ExposureType {
    Bias,
    Dark,
    Flat,
    Object,
}

const static std::map<ExposureType, std::string> ExposureTypeMap {
    {ExposureType::Bias,   "Bias"},
    {ExposureType::Dark,   "Dark"},
    {ExposureType::Flat,   "Flat"},
    {ExposureType::Object, "Object"}
};

class ExposureState {
public:
    explicit ExposureState(StateEnum state=StateEnum::Idle, float fullTime=0, float remTime=0)
    : state(state), fullTime(fullTime), remTime(remTime) {}
    StateEnum state;    ///< state
    double fullTime;    ///< full time for this state (sec)
    double remTime;     ///< remaining time for this state (sec)
};

} // namespace