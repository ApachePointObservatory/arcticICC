#!/usr/bin/env python2
from __future__ import absolute_import, division

import collections
import Tkinter

import RO.Wdg

UseArcticICC = False

if UseArcticICC:
    import arcticICC

    ExpTypeDict = collections.OrderedDict((
        ("Bias", arcticICC.ExposureType.Bias),
        ("Dark", arcticICC.ExposureType.Dark),
        ("Flat", arcticICC.ExposureType.Flat),
        ("Object", arcticICC.ExposureType.Object),
    ))
else:
    ExpTypeDict = collections.OrderedDict((
        ("Bias", "Bias"),
        ("Dark", "Dark"),
        ("Flat", "Flat"),
        ("Object", "Object"),
    ))

class CameraWdg(Tkinter.Frame):
    def __init__(self, master):
        Tkinter.Frame.__init__(self, master)
        exposeFrame = Tkinter.Frame(self)
        self.expNum = 1
        if UseArcticICC:
            self.camera = arcticICC.Camera(1024, 1024, 10)
        else:
            self.camera = None

        row = 0

        self.expTimeWdg = RO.Wdg.FloatEntry(exposeFrame, defaultVal = 1, minVal=0)
        self.expTimeWdg.pack(side="right")
        self.expTypeWdg = RO.Wdg.OptionMenu(
            master = exposeFrame,
            items = ExpTypeDict.keys(),
            defValue = "Object",
        )
        self.expTypeWdg.pack(side="right")
        self.expButton = RO.Wdg.Button(master=exposeFrame, text="Expose", command=self.doExpose)
        self.expButton.pack(side="right")
        exposeFrame.grid(row=row, column=0)
        row += 1

    def doExpose(self):
        expTime = self.expTimeWdg.get()
        expType = self.expTypeWdg.get()
        expTypeEnum = ExpTypeDict.get(expType)
        expName = "%s_%d.fits" % (expType, self.expNum)
        print "startExposure(%s, %s, %s)" % (expTime, expTypeEnum, expName)
        if UseArcticICC:
            self.camera.startExposure(expTime, expTypeEnum, expName)
        self.expNum += 1

if __name__ == "__main__":
    root = Tkinter.Tk()
    cameraWdg = CameraWdg(root)
    cameraWdg.pack()
    root.mainloop()
