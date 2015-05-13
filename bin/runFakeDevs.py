#!/usr/bin/env python2
from __future__ import division, absolute_import

from twisted.internet import reactor

from arcticICC.dev import FakeFilterWheel, FakeShutter

fwPort = 44444
fsPort = 55555

fw = FakeFilterWheel("fakeFilterWheel", fwPort)
fs = FakeShutter("fakeShutter", fsPort)
reactor.run()


