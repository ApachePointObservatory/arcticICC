from __future__ import division, absolute_import
"""arcticICC actor wrapper.
"""
from twistedActor import ActorWrapper
from .arcticActor import ArcticActor
from .dev import FilterWheelDeviceWrapper

__all__ = ["ArcticActorWrapper"]

class ArcticActorWrapper(ActorWrapper):
    """!A wrapper for the arcticICC talking to a fake camera, fake shutter, and fake filter wheel
    """
    def __init__(self, name, userPort=0, test=True):
        # if test=True use fake camera
        self.name = name
        self.test = test
        self.actor = None # the ArcticActor, once it's built
        self.filterDevWrapper = FilterWheelDeviceWrapper()
        ActorWrapper.__init__(self,
            deviceWrapperList = [self.filterDevWrapper],
            name = name,
            userPort = userPort,
            )

    def _makeActor(self):
        self.actor = ArcticActor(
            name = self.name,
            filterWheelDev = self.filterDevWrapper.device,
            userPort = self._userPort,
            test = self.test,
        )