#!/usr/bin/env python2
from __future__ import division, absolute_import

import unittest

from arcticICC import arcticCommandSet

commandList = [
    "set bin=2 window=full amps=auto filter=2 readoutRate=fast",
    "set bin=2 window=2,2,400,800 amps=auto filter=2 readoutRate=medium",
    "set bin=4 window=2,2,400,800 amps=auto filter=2 readoutRate=slow",
    "set bin=1 window=2,2,400,800 amps=auto filter=6 readoutRate=fast",
    "set bin=1,2 amps=quad window=0,2,400,800 filter=2 readoutRate=medium",
    "set bin=2,1 window=0,2,400,800 amps=auto filter=2 readoutRate=medium",
    "set bin=2,2 window=0,2,400,800 filter=2 amps=ll readoutRate=medium",
    "set bin=1 window=full amps=auto filter=2 readoutRate=medium",
    "set bin=1 window=0,0,400,800 amps=auto filter=4 readoutRate=medium",
    "set window=full",
    "set bin=1 window=full amps=auto readoutRate=fast",
    "expose object time=100",
    "expose object time=100 basename=test",
    "expose object time=100 basename=test/path",
    "expose object time=100 basename='test'",
    "Expose object time=100 basename='test/path'",
    "expose object time=100 basename=test comment=atest",
    "expose object time=100 basename=test comment='a comment with a test'",
    "expose object time=100 basename=test comment=\"a comment with a test\"",
    "exp obj tim=100 base=test comm=atest",
    "expose flat time=100",
    "expose flat time=100 basename=test",
    "expose flat time=100 basename=test/path",
    "expose flat time=100 basename='test'",
    "expose flat time=100 basename='test/path'",
    "expose flat time=100 basename=test comment=atest",
    "expose flat time=100 basename=test comment='a comment with a test'",
    "expose flat time=100 basename=test comment=\"a comment with a test\"",
    "expose pause",
    "expose resume",
    "expose stop",
    "expose abort",
    "camera status",
    "camera init",
    "filter status",
    "filter init",
    "filter home",
    "filter talk talk to camera text",
    "filter talk \"talk to camera text\"",
    "filter talk 'talk to camera text'",
    "init",
    "status",
]

badCommands = [
    "camera",
]

class TestParser(unittest.TestCase):
    def testCommandList(self):
        # cmdStr = "camera"
        # parsedCommand = arcticCommandSet.parse(cmdStr)

        for cmdStr in commandList:
            print "cmdStr: ", cmdStr
            parsedCommand = arcticCommandSet.parse(cmdStr)


if __name__ == '__main__':
    unittest.main()