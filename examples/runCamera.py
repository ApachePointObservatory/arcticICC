#!/usr/bin/env python2
from __future__ import absolute_import, division

import collections
import os
import Tkinter

import RO.Wdg
from RO.TkUtil import Timer

import arcticICC.camera as arctic

ExpTypeDict = collections.OrderedDict((
    ("Bias", arctic.Bias),
    ("Dark", arctic.Dark),
    ("Flat", arctic.Flat),
    ("Object", arctic.Object),
))

ReadoutRateDict = collections.OrderedDict((
    ("Slow", arctic.Slow),
    ("Medium", arctic.Medium),
    ("Fast", arctic.Fast),
))
StatusStrDict = {
    arctic.Idle:      "Idle",
    arctic.Exposing:  "Exposing",
    arctic.Paused:    "Paused",
    arctic.Reading:   "Reading",
    arctic.ImageRead: "ImageRead",
}

ReadoutAmpsDict = collections.OrderedDict((
    ("LL", arctic.LL),
    ("LR", arctic.LR),
    ("UR", arctic.UR),
    ("UL", arctic.UL),
    ("All", arctic.All),
))


class CameraWdg(Tkinter.Frame):
    def __init__(self, master):
        Tkinter.Frame.__init__(self, master)
        self.expNum = 1
        self.statusTimer = Timer()
        self.camera = arctic.Camera()

        row = 0

        exposeFrame = Tkinter.Frame(self)
        self.expTimeWdg = RO.Wdg.FloatEntry(
            master = exposeFrame,
            defValue = 1,
            minValue = 0,
            helpText = "exposure time (sec)",
        )
        self.expTimeWdg.pack(side="left")
        self.expTypeWdg = RO.Wdg.OptionMenu(
            master = exposeFrame,
            items = ExpTypeDict.keys(),
            defValue = "Object",
            helpText = "exposure type",
        )
        self.expTypeWdg.pack(side="left")
        self.expButton = RO.Wdg.Button(
            master = exposeFrame,
            text = "Expose",
            command = self.doExpose,
            helpText = "start exposure",
        )
        self.expButton.pack(side="left")
        exposeFrame.grid(row=row, column=0)
        row += 1

        binFrame = Tkinter.Frame(self)
        self.binXWdg = RO.Wdg.IntEntry(
            master = binFrame,
            defValue = 2,
            helpText = "x bin factor",
        )
        self.binXWdg.pack(side="left")
        self.binYWdg = RO.Wdg.IntEntry(
            master = binFrame,
            defValue = 2,
            helpText = "y bin factor",
        )
        self.binYWdg.pack(side="left")
        self.binBtn = RO.Wdg.Button(
            master = binFrame,
            command = self.doSetBin,
            text = "Set Bin Factor",
            helpText = "set bin factor",
        )
        self.binBtn.pack(side="left")
        binFrame.grid(row=row, column=0)
        row += 1

        readoutRateFrame = Tkinter.Frame(self)
        self.readoutRateWdg = RO.Wdg.OptionMenu(
            master = readoutRateFrame,
            items = ReadoutRateDict.keys(),
            defValue = "Medium",
            helpText = "set readout rate",
        )
        self.readoutRateWdg.pack(side="left")
        self.readoutRateBtn = RO.Wdg.Button(
            master = readoutRateFrame,
            command = self.doSetReadoutRate,
            text = "Set Readout Rate",
            helpText = "set readout rate",
        )
        self.readoutRateBtn.pack(side="left")
        readoutRateFrame.grid(row=row, column=0, sticky="w")
        row += 1

        readoutAmpsFrame = Tkinter.Frame(self)
        self.readoutAmpsWdg = RO.Wdg.OptionMenu(
            master = readoutAmpsFrame,
            items = ReadoutAmpsDict.keys(),
            defValue = "All",
            helpText = "set readout amps",
        )
        self.readoutAmpsWdg.pack(side="left")
        self.readoutAmpsBtn = RO.Wdg.Button(
            master = readoutAmpsFrame,
            command = self.doSetReadoutAmps,
            text = "Set Readout Amps",
            helpText = "set readout amps",
        )
        self.readoutAmpsBtn.pack(side="left")
        readoutAmpsFrame.grid(row=row, column=0, sticky="w")
        row += 1

        self.statusWdg = RO.Wdg.StrLabel(master=self)
        self.statusWdg.grid(row=row, column=0, sticky="w")
        row += 1

        self.statusBar = RO.Wdg.StatusBar(master=self)
        self.statusBar.grid(row=row, column=0, sticky="we")
        row += 1

        self.getStatus()

    def getStatus(self):
        try:
            expState = self.camera.getExposureState()
            statusStr = "%s %0.1f %0.1f" % (StatusStrDict.get(expState.state), expState.fullTime, expState.remTime)
            self.statusWdg.set(statusStr)
            if expState.state == arctic.ImageRead:
                self.camera.saveImage()
        finally:
            self.statusTimer.start(0.1, self.getStatus)

    def doExpose(self):
        expTime = self.expTimeWdg.getNum()
        expType = self.expTypeWdg.getString()
        expTypeEnum = ExpTypeDict.get(expType)
        expName = os.path.abspath("%s_%d.fits" % (expType, self.expNum))
        print "startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName)
        self.camera.startExposure(expTime, expTypeEnum, expName)
        self.expNum += 1

    def doSetBin(self):
        xBin = self.binXWdg.getNum()
        yBin = self.binYWdg.getNum()
        print "setBinFactor(%r, %r)" % (xBin, yBin)
        self.camera.setBinFactor(xBin, yBin)

    def doSetReadoutRate(self):
        readoutRateStr = self.readoutRateWdg.getString()
        print "setReadoutRate(%r)" % (readoutRateStr,)
        self.camera.setReadoutRate(ReadoutRateDict[readoutRateStr])

    def doSetReadoutAmps(self):
        readoutAmpsStr = self.readoutAmpsWdg.getString()
        print "setReadoutAmps(%r)" % (readoutAmpsStr,)
        self.camera.setReadoutAmps(ReadoutAmpsDict[readoutAmpsStr])


if __name__ == "__main__":
    root = Tkinter.Tk()
    cameraWdg = CameraWdg(root)
    cameraWdg.pack()
    root.mainloop()
