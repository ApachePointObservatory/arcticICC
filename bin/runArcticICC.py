#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
from twistedActor import startSystemLogging

from arcticICC import ArcticActor
from arcticICC.dev import FilterWheelDevice


try:
    startSystemLogging(ArcticActor.Facility)
    print("started systemLogging")
except KeyError as e:
   # don't start logging
   print("System Logging NOT!!!! Started")
   print(str(e))
# ports to match bin/runFakeDevs
UserPort = 35000
fwPort = 37000
fwAddress = "arctic-controller.apo.nmsu.edu"




if __name__ == "__main__":
    arcticActor = ArcticActor(
        filterWheelDev = FilterWheelDevice(
            host = fwAddress,
            port = fwPort,
            ),
        userPort = UserPort,
        )
    reactor.run()
