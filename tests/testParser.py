#!/usr/bin/env python2
from __future__ import division, absolute_import

import unittest

from arcticICC.cmd import

commandList = [
    "set bin=2 window=2,2,400,800 filter=2 temp=100",
    "set bin=4 window=2,2,400,800 filter=2 temp=100",
    "set bin=1 window=2,2,400,800 filter=u temp=100",
    "set bin=0 window=0,2,400,800 filter=2 temp=100",
    "set bin=0 window=0,2,400,800 filter=2 temp=1e10",
    "set bin=0 window=0,2,400,800 filter=2 temp=1E10",
    "set bin=0 window=0,2,400,800 filter=2 temp=100.6",
    "set bin=1 window=0,0,400,800 filter=g temp=100",
    "set bin=1 window=(0,0,400,800) filter='g' temp=100",
    "set bin=1 window=[0,0,400,800] filter=\"g\" temp=100",
    "set bin=1 window=full filter=r temp=100",
    "set bin=1 window=[full] filter=r temp=100",
    "expose object time=100",
    "expose object time=100 basename=test",
    "expose object time=100 basename=test/path",
    "expose object time=100 basename='test'",
    "expose object time=100 basename='test/path'",
    "expose object time=100 basename=test comment=atest",
    "expose object time=100 basename=test comment='a comment with a test'",
    "expose object time=100 basename=test comment=\"a comment with a test\"",
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

class TestParser(unittest.TestCase):
    pass

if __name__ == '__main__':
    unittest.main()