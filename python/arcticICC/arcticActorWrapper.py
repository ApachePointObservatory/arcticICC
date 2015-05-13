from __future__ import division, absolute_import
"""arcticICC actor wrapper.
"""
from twistedActor import ActorWrapper
from .arcticActor import ArcticActor
from .dev import ShutterDeviceWrapper, FilterWheelDeviceWrapper
from .fakeCamera import fakeCamera

__all__ = ["ArcticActorWrapper"]

class ArcticActorWrapper(ActorWrapper):
    """!A wrapper for the arcticICC talking to a fake camera, fake shutter, and fake filter wheel
    """
    def __init__(self, name, userPort=0):
        self.name = name
        self.actor = None # the ArcticActor, once it's built
        self.camera = fakeCamera.Camera()
        self.shutterDevWrapper = ShutterDeviceWrapper()
        self.filterDevWrapper = FilterWheelDeviceWrapper()
        ActorWrapper.__init__(self,
            deviceWrapperList = [self.shutterDevWrapper, self.filterDevWrapper],
            name = name,
            userPort = userPort,
            )

    def _makeActor(self):
        self.actor = ArcticActor(
            name = self.name,
            camera = self.camera,
            filterWheelDev = self.filterDevWrapper.device,
            shutterDev = self.shutterDevWrapper.device,
            userPort = self._userPort,
        )