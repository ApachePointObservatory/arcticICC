from __future__ import division, absolute_import
"""Device wrappers.
"""
from twistedActor import DeviceWrapper

from .fakeDev import FakeShutter, FakeFilterWheel
from .filterWheelDev import FilterWheelDevice
from .shutterDev import ShutterDevice

from arcticFilterWheel import ArcticFWActorWrapper

__all__ = ["ShutterDeviceWrapper", "FilterWheelDeviceWrapper"]

class ArcticDeviceWrapper(DeviceWrapper):
    """A wrapper for arctic devices and their faked controllers

    This wrapper is responsible for starting and stopping a fake controllers and
    the devices that talk to them:
    - It builds a fake controller construction
    - It builds a device when the fake controller is ready
    - It stops both on close()

    Public attributes include:
    - controller: the fake controller
    - device: the device (None until ready)
    - readyDeferred: called when the device and fake Galil are ready
      (for tracking closure use the Deferred returned by the close method, or stateCallback).
    """
    def __init__(self,
        devClass,
        fakeControllerClass,
        name = "",
        verbose = False,
        port = 0,
        debug = False,
    ):
        """Construct an ArcticDeviceWrapper that manages its fake controller

        @param[in] name  name of device
        @param[in] devClass either ShutterDevice or FakeFilterWheelDevice
        @param[in] port  the port for the fake Galil
        @param[in] debug  print debug messages to stdout?
        """
        self.devClass = devClass
        controller = fakeControllerClass(
            name = "fake" + name,
            port = port,
        )
        DeviceWrapper.__init__(self,
            name = name,
            controller = controller,
            debug = debug,
        )

    def _makeDevice(self):
        port = self.port
        if port is None:
            raise RuntimeError("Controller port is unknown")
        self.device = self.devClass(
            name = self.name,
            host="localhost",
            port=port,
        )

class ShutterDeviceWrapper(ArcticDeviceWrapper):
    def __init__(self,
        name = "shutterDevice",
        devClass = ShutterDevice,
        fakeControllerClass = FakeShutter,
        ):
        ArcticDeviceWrapper.__init__(self, devClass, fakeControllerClass, name)

class FilterWheelDeviceWrapperOld(ArcticDeviceWrapper):
    def __init__(self,
        name = "arcticfilterwheel",
        devClass = FilterWheelDevice,
        fakeControllerClass = FakeFilterWheel,
        ):
        ArcticDeviceWrapper.__init__(self, devClass, fakeControllerClass, name)

class FilterWheelDeviceWrapper(DeviceWrapper):
    """!A wrapper for an FilterWheelDevice talking to a fake filter wheel controller
    """
    def __init__(self,
        name="arcticfilterwheel",
        port=0
    ):
        """!Construct a FilterWheelDeviceWrapper that manages its fake mirror controller

        @param[in] name a name
        """
        controllerWrapper = ArcticFWActorWrapper(
            name="arcticFWActorWrapper",
        )
        DeviceWrapper.__init__(self, name=name, stateCallback=None, controllerWrapper=controllerWrapper)

    def _makeDevice(self):
        port = self.port
        if port is None:
            raise RuntimeError("Controller port is unknown")
        self.debugMsg("_makeDevice, port=%s" % (port,))
        self.device = FilterWheelDevice(
            host="localhost",
            port=port,
        )


