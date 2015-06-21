#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
from twistedActor import startSystemLogging

# import pdb; pdb.set_trace()

from arcticICC import ArcticActor
from arcticICC import camera
from arcticICC.dev import FilterWheelDevice, ShutterDevice

# ports to match bin/runFakeDevs
fwPort = 44444
fsPort = 55555

filterWheelDevice = FilterWheelDevice(
    name = "filterWheelDevice",
    host = "localhost",
    port = fwPort
    )

shutterDevice = ShutterDevice(
    name = "shutterDevice",
    host = "localhost",
    port = fsPort
    )

startSystemLogging(ArcticActor.Facility)

arcticActor = ArcticActor(
    camera = camera.Camera(),
    filterWheelDev = filterWheelDevice,
    shutterDev = shutterDevice
    )

reactor.run()
