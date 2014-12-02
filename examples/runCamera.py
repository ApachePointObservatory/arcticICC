#!/usr/bin/env python2
from __future__ import absolute_import, division

import collections
import Tkinter

import RO.Wdg
from RO.TkUtil import Timer

UseArcticICC = True

if UseArcticICC:
    import arcticICC.camera as arctic

    ExpTypeDict = collections.OrderedDict((
        ("Bias", arctic.ExposureType.Bias),
        ("Dark", arctic.ExposureType.Dark),
        ("Flat", arctic.ExposureType.Flat),
        ("Object", arctic.ExposureType.Object),
    ))

    ReadoutRateDict = collections.OrderedDict((
        ("Slow", arctic.ReadoutRate.Slow),
        ("Medium", arctic.ReadoutRate.Medium),
        ("Fast", arctic.ReadoutRate.Fast),
    ))
    StatusStrDict = {
        arctic.StateEnum.Idle:      "Idle",
        arctic.StateEnum.Exposing:  "Exposing",
        arctic.StateEnum.Paused:    "Paused",
        arctic.StateEnum.Reading:   "Reading",
        arctic.StateEnum.ImageRead: "ImageRead",
    }
else:
    ExpTypeDict = collections.OrderedDict((
        ("Bias", "Bias"),
        ("Dark", "Dark"),
        ("Flat", "Flat"),
        ("Object", "Object"),
    ))
    ReadoutRateDict = collections.OrderedDict((
        ("Slow", "Slow"),
        ("Medium", "Medium"),
        ("Fast", "Fast"),
    ))
    StatusStrDict = None

class CameraWdg(Tkinter.Frame):
    def __init__(self, master):
        Tkinter.Frame.__init__(self, master)
        self.expNum = 1
        self.statusTimer = Timer()
        if UseArcticICC:
            self.camera = arctic.Camera(1024, 1024, 10)
            self.getStatus()
        else:
            self.camera = None

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
            defValue = 1,
            helpText = "x bin factor",
        )
        self.binXWdg.pack(side="left")
        self.binYWdg = RO.Wdg.IntEntry(
            master = binFrame,
            defValue = 1,
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
            defValue = "Slow",
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

        self.statusWdg = RO.Wdg.StrLabel(master=self)
        self.statusWdg.grid(row=row, column=0, sticky="we")
        row += 1

        self.statusBar = RO.Wdg.StatusBar(master=self)
        self.statusBar.grid(row=row, column=0, sticky="we")
        row += 1

    def getStatus(self):
        expStatus = self.camera.getExposureStatus()
        statusStr = "%s %s %s" % (StatusStrDict.get(expStatus.state), expStatus.fullTime, expStatus.remTime)
        self.statusWdg.set(statusStr)
        self.statusTimer.start(0.1, self.getStatus)

    def doExpose(self):
        expTime = self.expTimeWdg.get()
        expType = self.expTypeWdg.getString()
        expTypeEnum = ExpTypeDict.get(expType)
        expName = "%s_%d.fits" % (expType, self.expNum)
        print "startExposure(%s, %s, %s)" % (expTime, expTypeEnum, expName)
        if UseArcticICC:
            self.camera.startExposure(expTime, expTypeEnum, expName)
        self.expNum += 1

    def doSetBin(self):
        xBin = self.binXWdg.get()
        yBin = self.binYWdg.get()
        print "set bin factor = %s, %s" % (xBin, yBin)
        if UseArcticICC:
            self.camera.setBinFactor(xBin, yBin)

    def doSetReadoutRate(self):
        readoutRateStr = self.readoutRateWdg.getString()
        print "set readout rate = %s" % (readoutRateStr,)
        if UseArcticICC:
            self.camera.setReadoutRate(ReadoutRateDict[readoutRateStr])


if __name__ == "__main__":
    root = Tkinter.Tk()
    cameraWdg = CameraWdg(root)
    cameraWdg.pack()
    root.mainloop()
