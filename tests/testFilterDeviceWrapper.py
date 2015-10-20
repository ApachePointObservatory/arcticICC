#!/usr/bin/env python2
from __future__ import division, absolute_import

import RO.Comm.Generic
RO.Comm.Generic.setFramework("twisted")
from twisted.trial.unittest import TestCase

from twistedActor import testUtils
testUtils.init(__file__)

from arcticICC.dev import FilterWheelDeviceWrapper

# class TestMirrorDeviceWrapper(TestCase):
#     """Test basics of MirrorDeviceWrapper
#     """
#     def setUp(self):
#         self.dw = FilterWheelDeviceWrapper()
#         return self.dw.readyDeferred

#     def tearDown(self):
#         d = self.dw.close()
#         return d

#     def testSetUpTearDown(self):
#         self.assertFalse(self.dw.didFail)
#         self.assertFalse(self.dw.isDone)
#         self.assertTrue(self.dw.isReady)


if __name__ == '__main__':
    from unittest import main
    main()
