#!/usr/bin/env python2
from __future__ import division, absolute_import
import os
import glob

from twisted.internet import reactor

from twisted.trial.unittest import TestCase
from twisted.internet.defer import Deferred

from twistedActor import testUtils, UserCmd#, log


testUtils.init(__file__)

import RO.Comm.Generic
RO.Comm.Generic.setFramework("twisted")

from arcticICC import ArcticActorWrapper
# from arcticICC import camera
from arcticICC import fakeCamera as camera
# from arcticICC.cmd import ParseError

# class TestArcticICC(TestCase):
#     """Tests for each command, and how they behave in collisions
#     """
#     def setUp(self):
#         # self.name = "arctic"
#         self.aw = ArcticActorWrapper(
#             name="arcticActorWrapper",
#         )
#         def setTestImageDir(cb):
#             testImagePath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data/images")
#             # remove any present test images, avoids overwrite errors
#             images = glob.glob(os.path.join(testImagePath, "*"))
#             for image in images:
#                 os.remove(image)
#             self.arcticActor.imageDir = testImagePath

#         d = self.aw.readyDeferred
#         d.addCallback(setTestImageDir)
#         # change the image directory to
#         return d

#     @property
#     def arcticActor(self):
#         return self.aw.actor

#     def commandActor(self, cmdStr, shouldFail=False):
#         d = Deferred()
#         cmd = UserCmd(cmdStr=cmdStr)
#         def fireDeferred(cbCmd):
#             if cbCmd.isDone:
#                 d.callback("done")
#                 print("fire deferred!")
#         def checkCmdState(cb):
#             self.assertTrue(shouldFail==cmd.didFail)
#         cmd.addCallback(fireDeferred)
#         d.addCallback(checkCmdState)
#         self.arcticActor.parseAndDispatchCmd(cmd)
#         return d

#     def tearDown(self):
#         print("tear down")
#         delayedCalls = reactor.getDelayedCalls()
#         for call in delayedCalls:
#             call.cancel()
#         return self.aw.close()

    # def testNothing(self):
    #     pass

    # def testStatus(self):
    #     return self.commandActor(cmdStr="status")

    # def testCameraStatus(self):
    #     return self.commandActor(cmdStr="camera status")

    # def testCameraInit(self):
    #     return self.commandActor(cmdStr="camera init")

    # def testSet0(self):
    #     d = self.commandActor(cmdStr="set bin=2 window=full amps=ll readoutRate=slow filter=0 temp=20")
    #     def checkSet(cb):
    #         config = self.arcticActor.camera.getConfig()
    #         self.assertTrue(config.binFacCol==2)
    #         self.assertTrue(config.binFacRow==2)
    #         self.assertTrue(config.winStartCol == 0)
    #         self.assertTrue(config.winStartRow == 0)
    #         self.assertTrue(config.winWidth == config.computeBinnedWidth(camera.CCDWidth))
    #         self.assertTrue(config.winHeight == config.computeBinnedHeight(camera.CCDHeight))
    #         self.assertTrue(config.isFullWindow())
    #         self.assertTrue(config.readoutRate == camera.Slow)
    #         self.assertTrue(config.readoutAmps == camera.LL)
    #         self.assertAlmostEqual(self.arcticActor.tempSetpoint, 20)
    #         self.assertTrue(self.arcticActor.filterWheelDev.status.position == 0)
    #     d.addCallback(checkSet)
    #     return d

    # # def testBadSet(self):
    # #     # cant get this one working correctly
    # #     # cant specify amps=quad AND a window!=full
    # #     return self.commandActor(cmdStr="set bin=[2,2] window=[20,40,60,70] amps=quad readout=med filter=1 temp=20", shouldFail=True)

    # def testSet1(self):
    #     d = self.commandActor(cmdStr="set bin=[2,2] window=[20,40,60,70] amps=auto readout=med filter=1 temp=20")
    #     def checkSet(cb):
    #         config = self.arcticActor.camera.getConfig()
    #         self.assertTrue(config.binFacCol==2)
    #         self.assertTrue(config.binFacRow==2)
    #         self.assertTrue(config.winStartCol == 19)
    #         self.assertTrue(config.winStartRow == 39)
    #         self.assertTrue(config.winWidth == 41)
    #         self.assertTrue(config.winHeight == 31)
    #         self.assertTrue(config.readoutRate == camera.Medium)
    #         self.assertTrue(config.readoutAmps == camera.LL)
    #         self.assertAlmostEqual(self.arcticActor.tempSetpoint, 20)
    #         self.assertTrue(self.arcticActor.filterWheelDev.status.position == 1)
    #     d.addCallback(checkSet)
    #     return d

    # def testSet2(self):
    #     d = self.commandActor(cmdStr="set bin=(4,2)  window=[40,20,70,90] amps=auto readoutRate=fast filter=2 temp=40.6")
    #     def checkSet(cb):
    #         config = self.arcticActor.camera.getConfig()
    #         self.assertTrue(config.binFacCol==4)
    #         self.assertTrue(config.binFacRow==2)
    #         self.assertTrue(config.winStartCol == 39)
    #         self.assertTrue(config.winStartRow == 19)
    #         self.assertTrue(config.winWidth == 31)
    #         self.assertTrue(config.winHeight == 71)
    #         self.assertTrue(config.readoutRate == camera.Fast)
    #         self.assertTrue(config.readoutAmps == camera.LL)
    #         self.assertAlmostEqual(self.arcticActor.tempSetpoint, 40.6)
    #         self.assertTrue(self.arcticActor.filterWheelDev.status.position == 2)
    #     d.addCallback(checkSet)
    #     return d

    # def testSet3(self):
    #     d = self.commandActor(cmdStr="set bin=1,4 readoutRate=slow window=20,40,60,70 amps=ll filter=0 temp=20")
    #     def checkSet(cb):
    #         config = self.arcticActor.camera.getConfig()
    #         self.assertTrue(config.binFacCol==1)
    #         self.assertTrue(config.binFacRow==4)
    #         self.assertTrue(config.winStartCol == 19)
    #         self.assertTrue(config.winStartRow == 39)
    #         self.assertTrue(config.winWidth == 41)
    #         self.assertTrue(config.winHeight == 31)
    #         self.assertTrue(config.readoutRate == camera.Slow)
    #         self.assertTrue(config.readoutAmps == camera.LL)
    #         self.assertAlmostEqual(self.arcticActor.tempSetpoint, 20)
    #         self.assertTrue(self.arcticActor.filterWheelDev.status.position == 0)
    #     d.addCallback(checkSet)
    #     return d

    # def testSet4(self):
    #     d = self.commandActor(cmdStr="set wind=full amps=quad bin=1,4 readoutRate=slow filter=0 temp=20")
    #     def checkSet(cb):
    #         config = self.arcticActor.camera.getConfig()
    #         self.assertTrue(config.binFacCol==1)
    #         self.assertTrue(config.binFacRow==4)
    #         self.assertTrue(config.winStartCol == 0)
    #         self.assertTrue(config.winStartRow == 0)
    #         self.assertTrue(config.winWidth == config.computeBinnedWidth(camera.CCDWidth))
    #         self.assertTrue(config.winHeight == config.computeBinnedHeight(camera.CCDHeight))
    #         self.assertTrue(config.readoutRate == camera.Slow)
    #         self.assertTrue(config.readoutAmps == camera.Quad)
    #         self.assertAlmostEqual(self.arcticActor.tempSetpoint, 20)
    #         self.assertTrue(self.arcticActor.filterWheelDev.status.position == 0)
    #     d.addCallback(checkSet)
    #     return d

    # def testFilter0(self):
    #     d = self.commandActor(cmdStr="filter status")
    #     return d

    # def testFilter1(self):
    #     d = self.commandActor(cmdStr="filter init")
    #     return d

    # def testFilter2(self):
    #     d = self.commandActor(cmdStr="filter home")
    #     return d

    # def testFilter3(self):
    #     d = self.commandActor(cmdStr="filter talk blah blue2 g\2")
    #     return d

    # def testExpose0(self):
    #     d = self.commandActor(cmdStr="expose bias")
    #     return d

    # def testExpose1(self):
    #     d = self.commandActor(cmdStr="expose object time=0")
    #     return d

    # def testExpose2(self):
    #     d = self.commandActor(cmdStr="expose flat time=0")
    #     return d

    # def testExpose3(self):
    #     d = self.commandActor(cmdStr="expose dark time=0")
    #     return d


if __name__ == '__main__':
    from unittest import main
    main()