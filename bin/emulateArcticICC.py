#!/usr/bin/env python2
from __future__ import absolute_import, division
# import subprocess


from twisted.internet import reactor

from twistedActor import startFileLogging

from arcticICC import ArcticActorWrapper

UserPort = 35000

try:
    startFileLogging("emulateArcticICC")
except KeyError:
   # don't start logging
   pass

if __name__ == "__main__":
    print("emulate arcticICC running on port %i"%UserPort)
    arcticICCWrapper = ArcticActorWrapper(name="mockArcticICC", userPort=UserPort)
    reactor.run()