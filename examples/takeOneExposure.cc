#include <iostream>
#include <chrono>
#include <thread>

#include "arcticICC/basics.h"
#include "arcticICC/camera.h"

int main() {
    arctic::Camera camera{};
    camera.setReadoutRate(arctic::ReadoutRate::Medium);
    camera.setWindow(0, 0, arctic::CCDWidth, arctic::CCDHeight);
    std::cout << "camera.startExposure(2, arctic::ExposureType::Object, 'object.fits')\n";
    camera.startExposure(2, arctic::ExposureType::Object, "object.fits");

    while (true) {
        std::cout << "camera.GetExposureState()\n";
        auto expStatus = camera.getExposureState();
        std::cout << "state=" << arctic::StateMap.find(expStatus.state)->second
            << "; fullTime=" << expStatus.fullTime
            << "; remTime=" << expStatus.remTime
            << std::endl;
        if (!expStatus.isBusy()) {
            break;
        }
        std::chrono::milliseconds dura(200);
        std::this_thread::sleep_for(dura);
    }
    std::cout << "camera.saveImage()\n";
    camera.saveImage();
    return 0;
}
