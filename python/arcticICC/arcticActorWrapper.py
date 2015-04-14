from __future__ import division, absolute_import
"""arcticICC actor wrapper.
"""
from twistedActor import ActorWrapper

from dev import ShutterDeviceWrapper, FilterWheelDeviceWrapper

__all__ = ["ArcticActorWrapper"]

class ArcticActorWrapper(ActorWrapper)
    """!A wrapper for the arcticICC talking to a fake camera, fake shutter, and fake filter wheel
    """
    def __init__(self):
        self.name = "arcticICC"
