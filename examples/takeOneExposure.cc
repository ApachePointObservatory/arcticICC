#include <iostream>
#include <chrono>
#include <thread>

#include "arcticICC/basics.h"
#include "arcticICC/camera.h"

int main() {
    arctic::Camera camera(4096, 4096, 50);
    camera.startExposure(2, arctic::ExposureType::Object, "object.fits");

    while (true) {
        auto expStatus = camera.getExposureState();
        std::cout << "state=" << arctic::StateMap.find(expStatus.state)->second
            << "; fullTime=" << expStatus.fullTime
            << "; remTime=" << expStatus.remTime
            << std::endl;
        if (!expStatus.isBusy()) {
            break;
        }
    }
    camera.saveImage();
    return 0;
}
