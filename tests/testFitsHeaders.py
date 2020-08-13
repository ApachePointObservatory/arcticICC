#!/usr/bin/env python2
from __future__ import division, absolute_import
import os
import glob

from astropy.io import fits

from twisted.internet import reactor

from twisted.trial.unittest import TestCase
from twisted.internet.defer import Deferred

from twistedActor import testUtils, UserCmd#, log


testUtils.init(__file__)

import RO.Comm.Generic
RO.Comm.Generic.setFramework("twisted")

from arcticICC import ArcticActorWrapper

TestDataPath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
TestImagePath = os.path.join(TestDataPath, "images")
TestFitsHeadersPath = os.path.join(TestDataPath, "fitsHeaders")
FileBaseName = "conortest.00"
FileExt = ".fits.txt"

class TestFitsHeaders(TestCase):
    """Tests for each command, and how they behave in collisions
    """
    def setUp(self):
        # self.name = "arctic"
        self.aw = ArcticActorWrapper(
            name="arcticActorWrapper",
        )
        def setTestImageDir(cb):
            # remove any present test images, avoids overwrite errors
            images = glob.glob(os.path.join(TestImagePath, "*"))
            for image in images:
                os.remove(image)
            self.arcticActor.imageDir = TestImagePath

        d = self.aw.readyDeferred
        d.addCallback(setTestImageDir)
        # change the image directory to
        return d

    def tearDown(self):
        delayedCalls = reactor.getDelayedCalls()
        for call in delayedCalls:
            call.cancel()
        return self.aw.close()

    @property
    def arcticActor(self):
        return self.aw.actor

    # def fakeHome(self):
    #     self.aw.deviceWrapperList[1].controller.status.isHomed = 1

    def commandActor(self, cmdStr, shouldFail=False):
        d = Deferred()
        cmd = UserCmd(cmdStr=cmdStr)
        def fireDeferred(cbCmd):
            if cbCmd.isDone:
                d.callback("done")
                # print("fire deferred!")
        def checkCmdState(cb):
            self.assertTrue(shouldFail==cmd.didFail)
        cmd.addCallback(fireDeferred)
        d.addCallback(checkCmdState)
        self.arcticActor.parseAndDispatchCmd(cmd)
        return d

    def parseFitsData(self, file):
        """return setCommandString, exposeCommandString, dictOfFitsData
        """
        fitsDataDict = {}
        with open(file, "r") as f:
            # first line is set command
            setCommand = f.readline()
            # second line is expose command
            exposeCommand = f.readline()
            # rest of file is fits cards to be parsed
            # they look like this
            # key=value #followed by a comment
            # first get the comment
            for line in f.readlines():
                if not line:
                    continue
                keyVal, comment = line.split("#", 1)
                key, val = keyVal.split("=")
                # strip any whitespace on comment or value
                comment = comment.strip()
                val = val.strip()
                # load em into the dict
                fitsDataDict[key] = (val, comment)
        return setCommand, exposeCommand, fitsDataDict

    def test2(self):
        imgNum = "02"
        return self._testHeader(imgNum)

    def test3(self):
        imgNum = "03"
        return self._testHeader(imgNum)

    def test4(self):
        imgNum = "04"
        return self._testHeader(imgNum)

    def test5(self):
        imgNum = "05"
        return self._testHeader(imgNum)

    def test6(self):
        imgNum = "06"
        return self._testHeader(imgNum)

    def test7(self):
        imgNum = "07"
        return self._testHeader(imgNum)

    def test8(self):
        imgNum = "08"
        return self._testHeader(imgNum)

    def test9(self):
        imgNum = "09"
        return self._testHeader(imgNum)

    def test10(self):
        imgNum = "10"
        return self._testHeader(imgNum)

    def test11(self):
        imgNum = "11"
        return self._testHeader(imgNum)

    def _verifyFitsDict(self, foo, fitsDict, returnDeferred):
        # find the image that was last written
        # should be the only on in the image directory
        imageFile = glob.glob(os.path.join(TestImagePath, "*.fits"))
        self.assertTrue(len(imageFile)==1, "Found multiple or no images in image directory, expecting only one")
        hdulist = fits.open(imageFile[0])
        prihdr = hdulist[0].header
        for key, (val, comment) in fitsDict.iteritems():
            self.assertTrue(key in prihdr, "Couldn't find key %s in image header"%key)
            self.assertTrue(prihdr.comments[key] == comment, "Comment doesn't match %s, %s"%(prihdr.comments[key], comment))
            # ignore a few values that won't match
            if key in ["filter", "filpos", "date-obs", "begx", "begy", "exptime"]:
                # begx/y have changed
                continue
            elif key == "exptime":
                self.assertTrue(float(prihdr[key]) == float(val), "Value doesn't match %s, %s for key: %s"%(prihdr[key], val, key))
            else:
                self.assertTrue(str(prihdr[key]).strip() == val.strip(), "Values doesn't match %s, %s for key: %s"%(prihdr[key], val, key))
        returnDeferred.callback(None)

    def _testHeader(self, imgNum):
        # img num is a string
        returnDeferred = Deferred()
        testFile = FileBaseName + imgNum + FileExt
        filePath = os.path.join(TestFitsHeadersPath, testFile)
        setCmd, exposeCmd, fitsDict = self.parseFitsData(filePath)
        def sendExposeCmd(foo):
            exposeD = self.commandActor(cmdStr=exposeCmd)
            exposeD.addCallback(self._verifyFitsDict, fitsDict, returnDeferred)
        setD = self.commandActor(cmdStr=setCmd)
        setD.addCallback(sendExposeCmd)
        return returnDeferred



if __name__ == '__main__':
    from unittest import main
    main()
