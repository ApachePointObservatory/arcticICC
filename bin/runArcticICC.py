#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
from twistedActor import startFileLogging

from arcticICC import ArcticActorWrapper

UserPort = 35000

try:
    startFileLogging("/home/arctic/logs/arcticICC")
except KeyError:
   # don't start logging
   pass

if __name__ == "__main__":
    print("arcticICC running on port %i"%UserPort)
    arcticICCWrapper = ArcticActorWrapper(name="arcticICC", userPort=UserPort, test=False)
    reactor.run()