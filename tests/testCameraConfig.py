#!/usr/bin/env python2
from __future__ import division, absolute_import
import os

import unittest

import arcticICC

from arcticICC.fakeCamera import Camera

configs = [Camera().getConfig()]
if os.getenv("HOSTNAME") == "arctic-icc.apo.nmsu.edu":
    configs.append(arcticICC.camera.Camera().getConfig())

class TestCameraConfig(unittest.TestCase):
    def testAllMethods(self):
        """Test that all methods work on the fake config and additionally
        real if we are on the real system
        """
        methods = [
            "assertValid",
            "canWindow",
            "getNumAmps",
            "setFullWindow",
            "getUnbinnedWidth",
            "getUnbinnedHeight",
            "getBinnedWidth",
            "getBinnedHeight",
            "isFullWindow",
            "getMaxWidth",
            "getMaxHeight",
        ]
        for methodName in methods:
            for config in configs:
                getattr(config, methodName)()



if __name__ == '__main__':
    unittest.main()