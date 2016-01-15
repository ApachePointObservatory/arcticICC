#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
from twistedActor import startSystemLogging

import arcticICC

UserPort = arcticICC.UserPort
from arcticICC import ArcticActor
from arcticICC.dev import FilterWheelDevice, ShutterDevice, FakeShutter


try:
    startSystemLogging(ArcticActor.Facility)
except KeyError:
   # don't start logging
   pass

# ports to match bin/runFakeDevs
fwPort = 37000
# oldIP 10.50.1.245
fwAddress = "arctic-controller.apo.nmsu.edu" # "localhost"
fsPort = 55555


def startDevs(fs):
    if fs.isReady:
        filterWheelDevice = FilterWheelDevice(
            host = fwAddress,
            port = fwPort,
            )

        shutterDevice = ShutterDevice(
            name = "shutterDevice",
            host = "localhost",
            port = fsPort,
            )

        arcticActor = ArcticActor(
            filterWheelDev = filterWheelDevice,
            shutterDev = shutterDevice,
            )


if __name__ == "__main__":
    fs = FakeShutter("fakeShutter", fsPort)
    fs.addStateCallback(startDevs)
    reactor.run()
