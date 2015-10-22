from __future__ import division, absolute_import

import os

import RO

from twistedActor import expandUserCmd, ActorDevice, log

__all__ = ["FilterWheelDevice"]

"""
    put this model into tui
    Key("state",
        String(help="State of device, one of: Moving, Done, Homing, Failed, NotHomed"),
        Float(invalid="NaN", units="seconds", help="remaining time for command, if known, else 0"),
        Float(invalid="NaN", units="seconds", help="total time for command, if known, else 0"),
        help = "summarizes current state of the filter wheel",
    ),
"""

class KWForwarder(object):
    fwKeywords = [
        "wheelID",
        # "filterID",
        "encoderPos",
        "desiredStep",
        "currentStep"
    ]
    def __init__(self, actor):
        """! Construct a KWForwarder.  A class for formatting and forwarding KW received the arctic filter wheel
                to be passed along to TUI and other users.

        @param[in] actor. ActorDispatcher instance.
        """
        self.actor = actor
        for kw in self.fwKeywords:
            # all these get simply forwarded
            getattr(self.model, kw).addValueCallback(self.forwardKW, callNow = True)
        # ouput available filter names with the wheelID
        self.model.wheelID.addValueCallback(self.actor.outputFilterNames, callNow = True)
        # self.model.wheelID.addValueCallback(self.actor.outputCurrFilter, callNow = True)
        # self.model.wheelID.addValueCallback(self.actor.outputCmdFilter, callNow = True)
        # output the current filter name with the filterID
        self.model.filterID.addValueCallback(self.actor.outputCurrFilter, callNow = True)
        self.model.cmdFilterID.addValueCallback(self.actor.outputCmdFilter, callNow = True)
        self.model.state.addValueCallback(self.actor.outputFilterState, callNow = True)
        # for kw in ["isMoving", "isHomed", "isHoming"]:
        #     # all these keywords output the state keyword
        #     getattr(self.model, kw).addValueCallback(self.actor.outputFilterState, callNow = True)


    @property
    def model(self):
        return self.actor.dispatcher.model

    @property
    def writeToUsers(self):
        return self.actor.writeToUsers

    def printKW(self, value, isCurrent, keyVar):
        print("value %s, isCurrent %s, keyVar %s"%(str(value), str(isCurrent), str(keyVar)))

    def forwardKW(self, value, isCurrent, keyVar):
        """
        @todo add automatic forwarding of warnings too...
        """
        msgCode = keyVar.reply.header.code if keyVar.reply else "i"
        strValList = []
        for value in keyVar.valueList:
            strValList.append(str(value) if value!=None else "NaN")
        # prepend name to msg keyword
        msgStr = '%s=%s' % (keyVar.name, ','.join(strValList))
        if not msgStr:
            return
        self.writeToUsers(msgCode=msgCode.lower(), msgStr=msgStr)


class FilterWheelDevice(ActorDevice):
    """!A FilterWheel Device
    """
    DefaultTimeLim = None # a poor choice, but the best we can do until commands pay attention to predicted duration
    def __init__(self,
        host,
        port,
        name = "arcticfilterwheel"
    ):
        """!Construct a FilterWheelDevice

        @param[in] host  mirror controller host
        @param[in] port  mirror controller port
        @paramp[in] name name of the device (should match model name in actorkeys)
        """
        # self.lastFilterState = None
        ActorDevice.__init__(self,
            name=name,
            host=host,
            port=port,
        )
        # self.kwForwarder = KWForwarder(self.dispatcher.model, self.writeToUsers)
        self.kwForwarder = KWForwarder(self)

    @property
    def model(self):
        return self.dispatcher.model

    @property
    def filterPos(self):
        """! Integer filter position
        """
        return self.model.filterID.valueList[0]

    @property
    def cmdFilterPos(self):
        """! Integer filter position
        """
        return self.model.cmdFilterID.valueList[0]

    @property
    def filterNames(self):
        """! Get the filter names for a given wheelID

        @param[in] wheelID  int, wheel number

        filter name files are expected in ~/filterNames/ directory
        and are named fw1.txt, fw2.txt, ...
        file structure is simple:

        1 SDSS u
        2 SDSS g


        ...
        number name

        """
        wheelID = self.model.wheelID.valueList[0]
        if wheelID is None:
            return []
        else:
            wheelID = int(wheelID)
        if wheelID == 0:
            # no wheel loaded!
            return []
        fileName = "fw%i.txt"%wheelID
        homeDir = os.getenv("HOME")
        filePath = os.path.join(homeDir, "filterNames", fileName)
        with open(filePath, "r") as f:
            lines = f.readlines()
        filterNameList = []
        for line in lines:
            filterNum, filterName = line.split(None, 1)
            filterNameList.append(filterName.strip())
        return filterNameList

    @property
    def filterName(self):
        """! Integer filter position

        return a string
        """
        # filterID updated output filterID and filterName
        # filterNames = self.filterNames
        try:
            return self.filterNames[int(self.filterPos)-1]
        except:
            return "?"
        # if not filterNames or self.filterPos is None:
        #     return "?"
        # else:
        #     return self.filterNames[int(self.filterPos)-1]

    @property
    def cmdFilterName(self):
        """! Integer filter position

        return a string
        """
        try:
            return self.filterNames[int(self.cmdFilterPos)-1]
        except:
            return "?"

        # filterID updated output filterID and filterName
        # filterNames = self.filterNames
        # if not filterNames or self.cmdFilterPos is None:
        #     return "?"
        # else:
        #     return self.filterNames[int(self.cmdFilterPos)-1]

    @property
    def filterState(self):
        return self.model.state.valueList[0]

    def outputFilterNames(self, value, isCurrent, keyVar):
        """output all available filter names, get them from file in home directory
        """
        filterNameStr = ", ".join([RO.StringUtil.quoteStr(name) for name in self.filterNames])
        self.writeToUsers(msgCode="i", msgStr="filterNames=%s"%(filterNameStr,))

    def outputCurrFilter(self, value, isCurrent, keyVar):
        filterID = self.model.filterID.valueList[0]
        try:
            filterID = "%i"%(filterID,)
        except:
            filterID = "NaN"
        filterName = RO.StringUtil.quoteStr(self.filterName)
        self.writeToUsers(msgCode="i", msgStr="currFilter=%s, %s"%(filterID, filterName))

    def outputCmdFilter(self, value, isCurrent, keyVar):
        filterID = self.model.cmdFilterID.valueList[0]
        try:
            filterID = "%i"%(filterID,)
        except:
            filterID = "NaN"
        filterName = RO.StringUtil.quoteStr(self.cmdFilterName)
        self.writeToUsers(msgCode="i", msgStr="cmdFilter=%s, %s"%(filterID, filterName))

    def outputFilterState(self, value, isCurrent, keyVar):
        msgCode = "i"
        state = self.filterState
        # if state == self.lastFilterState:
        #     # state unchanged, don't output
        #     print "state", state
        #     return
        # self.lastFilterState = state
        if state in ["Homing", "NotHomed"]:
            msgCode = "w"
        self.writeToUsers(msgCode=msgCode, msgStr="filterState=%s, 0, 0"%(state,))


    def init(self, userCmd=None, timeLim=10, getStatus=True):
        """!Initialize the device and cancel all pending commands

        @param[in] userCmd  user command that tracks this command, if any
        @param[in] timeLim  maximum time before command expires, in sec; None for no limit
        @param[in] getStatus  IGNORED (status is automatically output sometime after stop)
        @return userCmd (a new one if the provided userCmd is None)
        """
        userCmd = expandUserCmd(userCmd)
        self.startCmd(cmdStr="init", userCmd=userCmd, timeLim=timeLim)
        return userCmd

    def handleReply(self, reply):
        """!Called each time a reply comes through the line
        """
        print "%s.handleReply(reply=%r)" % (self, reply)
        log.info("%s read %r" % (self, reply))

    def startCmd(self, cmdStr, userCmd=None, callFunc=None, timeLim=0.):
        log.info("%s.startCmd(cmdStr=%s, userCmd=%s, callFunc=%s)"%(self, cmdStr, str(userCmd), str(callFunc)))
        # print("%s.startCmd(cmdStr=%s, userCmd=%s, callFunc=%s)"%(self, cmdStr, str(userCmd), str(callFunc)))
        return ActorDevice.startCmd(self, cmdStr=cmdStr, userCmd=userCmd, callFunc=callFunc, timeLim=timeLim)

