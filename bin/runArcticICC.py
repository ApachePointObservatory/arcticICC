#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
# from twistedActor import startSystemLogging
from twistedActor import startFileLogging

from arcticICC import ArcticActor
from arcticICC.dev import FilterWheelDevice, ShutterDevice


UserPort = 35000

try:
    startFileLogging("./arcticICC")
except KeyError:
   # don't start logging
   pass

# ports to match bin/runFakeDevs
fwPort = 37000
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

# startSystemLogging(ArcticActor.Facility)

arcticActor = ArcticActor(
    filterWheelDev = filterWheelDevice,
    shutterDev = shutterDevice
    )

reactor.run()


# if __name__ == "__main__":
#     print("arcticICC running on port %i"%UserPort)
#     arcticICCWrapper = ArcticActorWrapper(name="arcticICC", userPort=UserPort)
#     reactor.run()