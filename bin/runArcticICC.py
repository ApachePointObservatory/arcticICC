#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Run the Arctic ICC actor
"""
from twisted.internet import reactor
from twistedActor import startSystemLogging

# import pdb; pdb.set_trace()

from arcticICC import ArcticActor

startSystemLogging(ArcticActor.Facility)
arcticActor = ArcticActor()
reactor.run()
