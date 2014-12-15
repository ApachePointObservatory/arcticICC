#!/usr/bin/env python2
from __future__ import absolute_import, division
"""A simple interface to the Camera object

to do: for each call to status, get the current config and use it to update the default values of the widgets;
change the widgets to showIsCurrent so this is more visible.
"""
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

ReadoutAmpsNameEnumDict = collections.OrderedDict((
    ("LL", arctic.LL),
    ("LR", arctic.LR),
    ("UR", arctic.UR),
    ("UL", arctic.UL),
    ("All", arctic.All),
))
ReadoutAmpsEnumNameDict = collections.OrderedDict((enum, name) for (name, enum) in ReadoutAmpsNameEnumDict.iteritems())

ReadoutRateNameEnumDict = collections.OrderedDict((
    ("Slow", arctic.Slow),
    ("Medium", arctic.Medium),
    ("Fast", arctic.Fast),
))
ReadoutRateEnumNameDict = collections.OrderedDict((enum, name) for (name, enum) in ReadoutRateNameEnumDict.iteritems())

StatusStrDict = {
    arctic.Idle:      "Idle",
    arctic.Exposing:  "Exposing",
    arctic.Paused:    "Paused",
    arctic.Reading:   "Reading",
    arctic.ImageRead: "ImageRead",
}


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
        self.colBinFacWdg = RO.Wdg.IntEntry(
            master = binFrame,
            defValue = 2,
            autoIsCurrent = True,
            helpText = "x bin factor",
        )
        self.colBinFacWdg.pack(side="left")
        self.rowBinFacWdg = RO.Wdg.IntEntry(
            master = binFrame,
            defValue = 2,
            autoIsCurrent = True,
            helpText = "y bin factor",
        )
        self.rowBinFacWdg.pack(side="left")
        binFrame.grid(row=row, column=0)
        row += 1

        windowFrame = Tkinter.Frame(self)
        self.winColStartWdg = RO.Wdg.IntEntry(
            master = windowFrame,
            defValue = 0,
            autoIsCurrent = True,
            helpText = "window starting column",
        )
        self.winColStartWdg.pack(side="left")
        self.winRowStartWdg = RO.Wdg.IntEntry(
            master = windowFrame,
            defValue = 0,
            autoIsCurrent = True,
            helpText = "window starting row",
        )
        self.winRowStartWdg.pack(side="left")
        self.winWidthWdg = RO.Wdg.IntEntry(
            master = windowFrame,
            defValue = 0,
            autoIsCurrent = True,
            helpText = "window width (unbinned pixels)",
        )
        self.winWidthWdg.pack(side="left")
        self.winHeightWdg = RO.Wdg.IntEntry(
            master = windowFrame,
            defValue = 0,
            autoIsCurrent = True,
            helpText = "window height (unbinned pixels)",
        )
        self.winHeightWdg.pack(side="left")
        windowFrame.grid(row=row, column=0)
        row += 1

        self.fullWindowBtn = RO.Wdg.Button(
            master = self,
            command = self.doSetFullWindow,
            text = "Set Full Window",
            helpText = "set full window",
        )
        self.fullWindowBtn.grid(row=row, column=0)
        row += 1

        self.readoutRateWdg = RO.Wdg.OptionMenu(
            master = self,
            items = ReadoutRateNameEnumDict.keys(),
            defValue = "Medium",
            autoIsCurrent = True,
            helpText = "set readout rate",
        )
        self.readoutRateWdg.grid(row=row, column=0, sticky="w")
        row += 1

        self.readoutAmpsWdg = RO.Wdg.OptionMenu(
            master = self,
            items = ReadoutAmpsNameEnumDict.keys(),
            defValue = "All",
            autoIsCurrent = True,
            helpText = "set readout amps",
        )
        self.readoutAmpsWdg.grid(row=row, column=0, sticky="w")
        row += 1

        self.setConfigBtn = RO.Wdg.Button(
            master = self,
            command = self.doSetConfig,
            text = "Set Config",
            helpText = "set config",
        )
        self.setConfigBtn.grid(row=row, column=0, sticky="w")
        row += 1

        self.fileNameWdg = RO.Wdg.StrLabel(
            master = self,
            helpText = "file name",
        )
        self.fileNameWdg.grid(row=row, column=0, sticky="w")
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

        camConfig = self.camera.getConfig()
        self.readoutRateWdg.setDefault(ReadoutRateEnumNameDict[camConfig.readoutRate])
        self.readoutAmpsWdg.setDefault(ReadoutAmpsEnumNameDict[camConfig.readoutAmps])
        self.colBinFacWdg.setDefault(camConfig.colBinFac)
        self.rowBinFacWdg.setDefault(camConfig.rowBinFac)
        self.winColStartWdg.setDefault(camConfig.winColStart)
        self.winRowStartWdg.setDefault(camConfig.winRowStart)
        self.winWidthWdg.setDefault(camConfig.winWidth)
        self.winHeightWdg.setDefault(camConfig.winHeight)

    def doExpose(self):
        expTime = self.expTimeWdg.getNum()
        expType = self.expTypeWdg.getString()
        expTypeEnum = ExpTypeDict.get(expType)
        expName = os.path.abspath("%s_%d.fits" % (expType, self.expNum))
        self.fileNameWdg.set(expName)
        print "startExposure(%r, %r, %r)" % (expTime, expTypeEnum, expName)
        self.camera.startExposure(expTime, expTypeEnum, expName)
        self.expNum += 1

    def doSetConfig(self):
        config = self.camera.getConfig()
        readoutAmpsStr = self.readoutAmpsWdg.getString()
        config.readoutAmps = ReadoutAmpsNameEnumDict[readoutAmpsStr]
        readoutRateStr = self.readoutRateWdg.getString()
        config.readoutRate = ReadoutRateNameEnumDict[readoutRateStr]
        config.colBinFac = self.colBinFacWdg.getNum()
        config.rowBinFac = self.rowBinFacWdg.getNum()
        config.winColStart = self.winColStartWdg.getNum()
        config.winRowStart = self.winRowStartWdg.getNum()
        config.winWidth = self.winWidthWdg.getNum()
        config.winHeight = self.winHeightWdg.getNum()
        self.camera.setConfig(config)
        print "canWindow=", config.canWindow()
        print "isFullWindow=", config.isFullWindow()
        print "winWidth=", config.winWidth
        print "winHeight=", config.winHeight
        print "binnedWidth=", config.getBinnedWidth()
        print "binnedHeight=", config.getBinnedHeight()

    def doSetFullWindow(self):
        config = self.camera.getConfig()
        config.setFullWindow()
        self.winColStartWdg.set(config.winColStart)
        self.winRowStartWdg.set(config.winRowStart)
        self.winWidthWdg.set(config.winWidth)
        self.winHeightWdg.set(config.winHeight)


if __name__ == "__main__":
    root = Tkinter.Tk()
    cameraWdg = CameraWdg(root)
    cameraWdg.pack()
    root.mainloop()
