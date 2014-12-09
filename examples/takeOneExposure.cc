#include <iostream>
#include <chrono>
#include <thread>

#include "arcticICC/basics.h"
#include "arcticICC/camera.h"

int main() {
    arcticICC::Camera camera{};
    std::cout << "camera.startExposure(2, arcticICC::ExposureType::Object, 'object.fits')\n";
    camera.startExposure(2, arcticICC::ExposureType::Object, "object.fits");

    while (true) {
        auto expStatus = camera.getExposureState();
        std::cout << "exposure state=" << arcticICC::StateNameMap.find(expStatus.state)->second
            << "; fullTime=" << expStatus.fullTime
            << "; remTime=" << expStatus.remTime
            << std::endl;
        if (!expStatus.isBusy()) {
            break;
        }
        std::chrono::milliseconds dura{200};
        std::this_thread::sleep_for(dura);
    }
    std::cout << "camera.saveImage()\n";
    camera.saveImage();

    std::cout << "wait 3 seconds\n";
    std::chrono::milliseconds dura(3000);
    std::this_thread::sleep_for(dura);

    std::cout << "camera.startExposure(2, arcticICC::ExposureType::Object, 'object2.fits')\n";
    camera.startExposure(2, arcticICC::ExposureType::Object, "object2.fits");

    while (true) {
        auto expStatus = camera.getExposureState();
        std::cout << "exposure state=" << arcticICC::StateNameMap.find(expStatus.state)->second
            << "; fullTime=" << expStatus.fullTime
            << "; remTime=" << expStatus.remTime
            << std::endl;
        if (!expStatus.isBusy()) {
            break;
        }
        std::chrono::milliseconds dura{200};
        std::this_thread::sleep_for(dura);
    }
    std::cout << "camera.saveImage()\n";
    camera.saveImage();

    return 0;
}
