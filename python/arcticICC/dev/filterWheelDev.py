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
        "filterID",
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
        self.model.wheelID.addValueCallback(self.outputFilterNames, callNow = True)
        self.model.wheelID.addValueCallback(self.outputFilterName, callNow = True)
        # output the current filter name with the filterID
        self.model.filterID.addValueCallback(self.outputFilterName, callNow = True)
        for kw in ["isMoving", "isHomed", "isHoming"]:
            # all these keywords output the state keyword
            getattr(self.model, kw).addValueCallback(self.state, callNow = True)


    @property
    def model(self):
        return self.actor.dispatcher.model

    @property
    def writeToUsers(self):
        return self.actor.writeToUsers

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
            return ["no wheel loaded"]
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

    def outputFilterNames(self, value, isCurrent, keyVar):
        """output all available filter names, get them from file in home directory
        """
        filterNameStr = ", ".join([RO.StringUtil.quoteStr(name) for name in self.filterNames])
        self.writeToUsers(msgCode="i", msgStr="filterNames=%s"%(filterNameStr,))

    def outputFilterName(self, value, isCurrent, keyVar):
        # filterID updated output filterID and filterName
        filterNames = self.filterNames
        if not filterNames:
            return
        # is a wheel loaded?
        if filterNames[0] == "no wheel loaded":
            filterNameStr = RO.StringUtil.quoteStr(filterNames[0])
        else:
            filterID = self.model.filterID.valueList[0]
            if filterID is None:
                return
            filterID = int(filterID)
            filterNameStr = RO.StringUtil.quoteStr(filterNames[filterID-1]) # zero indexed
        self.writeToUsers(msgCode="i", msgStr="filterName=%s"%(filterNameStr,))

    def state(self, value, isCurrent, keyVar):
        # filter wheel state updated output new state
        homing = self.model.isHoming.valueList[0]
        homed = self.model.isHomed.valueList[0]
        moving = self.model.isMoving.valueList[0]
        state = "Done"
        msgCode = "i"
        if homing is not None and bool(homing):
            state = "Homing"
            msgCode = "w"
        elif homed is not None and not bool(homed):
            state = "NotHomed"
            msgCode = "w"
        elif moving is not None and bool(moving):
            state = "Moving"
        self.writeToUsers(msgCode=msgCode, msgStr="state=%s"%(state,))

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


    # def forwardWarining(self, value, isCurrent, keyVar):
    #     """!KeyVar callback on KeyVar objects that the TCC cares about
    #     simply forwards on the keyword with a mirror name prepended

    #     placeholder for now, forward warnings eventually!
    #     """
    #     # if this is text, don't prepend the mirror name, just forward as is
    #     msgCode = keyVar.reply.header.code if keyVar.reply else "i"
    #     if keyVar.name.lower() == "text":
    #         # only forward if it is a warning or higher
    #         if msgCode in ["e", "w"]:
    #             mirNameUp = ""
    #             keyVarNameUp = keyVar.name
    #             msgStr = "Text=" + "\"" + str(keyVar.valueList[0]) + "\""
    #             # import pdb; pdb.set_trace()
    #         else:
    #             # do nothing
    #             return

# FilterEnumNameDict = collections.OrderedDict((
#     (1, RO.StringUtil.quoteStr("SDSS u")),
#     (2, RO.StringUtil.quoteStr("SDSS g")),
#     (3, RO.StringUtil.quoteStr("SDSS r")),
#     (4, RO.StringUtil.quoteStr("SDSS i")),
#     (5, RO.StringUtil.quoteStr("SDSS z")),
#     (6, RO.StringUtil.quoteStr("place holder")),
# ))

# class FilterWheelStatus(object):
#     def __init__(self):
#         self.isMoving = False
#         self.position = 0

#     def getStatusStr(self):
#         # filterNames = "filterNames=?"
#         # filterID = "filterID=1"
#         # filterName = "filterName=?"

#         filterNames = "filterNames=" + ", ".join(FilterEnumNameDict.values())
#         filterID = "filterID=%i"%(self.position+1)
#         if self.position == 0:
#             filterName="?"
#         else:
#             filterName = "filterName=%s"%(FilterEnumNameDict[self.position])
#         return "; ".join([filterNames, filterID, filterName])


class FilterWheelDevice(ActorDevice):
    """!A Mirror Device
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

    # def _statusCallback(self, cmd):
    #     """! When status command is complete, send info to users
    #     """
    #     if cmd.isDone:
    #         self.writeToUsers("i", self.status.getStatusStr(), cmd)

    # def getStatus(self, userCmd=None):
    #     """!Query the device for status
    #     @param[in] userCmd  a twistedActor.BaseCommand
    #     """
    #     userCmd = expandUserCmd(userCmd)
    #     self.startCmd("status", userCmd=userCmd, callFunc=self._statusCallback)
    #     # userCmd.addCallback(self._statusCallback)
    #     return userCmd

    def handleReply(self, reply):
        """!Called each time a reply comes through the line
        """
        print "%s.handleReply(reply=%r)" % (self, reply)
        log.info("%s read %r" % (self, reply))

    def startCmd(self, cmdStr, userCmd=None, callFunc=None, timeLim=0.):
        log.info("%s.startCmd(cmdStr=%s, userCmd=%s, callFunc=%s)"%(self, cmdStr, str(userCmd), str(callFunc)))
        print("%s.startCmd(cmdStr=%s, userCmd=%s, callFunc=%s)"%(self, cmdStr, str(userCmd), str(callFunc)))
        return ActorDevice.startCmd(self, cmdStr=cmdStr, userCmd=userCmd, callFunc=callFunc, timeLim=timeLim)



    # @property
    # def timeLimKeyVar(self):
    #     """!Return a tuple containing the time limit keyvar and index for use in setting automatically
    #     updating time limits
    #     """
    #     return (self.dispatcher.model.state, 4)

    # def move(self, position, userCmd=None):
    #     """!Move the filter wheel to the wanted position

    #     @param[in] position  an integer
    #     @param[in] userCmd  a twistedActor.BaseCommand
    #     """
    #     userCmd = expandUserCmd(userCmd)
    #     self.startCmd("move %i"%position, userCmd=userCmd)
    #     return userCmd

    # def status(self, userCmd=None):
    #     """!Get FW status
    #     @param[in] userCmd  a twistedActor.BaseCommand
    #     """
    #     userCmd = expandUserCmd(userCmd)
    #     self.startCmd("status", userCmd=userCmd)
    #     return userCmd


# class FilterWheelDeviceOld(BaseDevice):
#     def __init__(self, name, host, port, callFunc=None):
#         """!Construct an FilterWheelDevice

#         Inputs:
#         @param[in] name  name of device
#         @param[in] host  host address of Galil controller
#         @param[in] port  port of Galil controller
#         @param[in] callFunc  function to call when state of device changes;
#                 note that it is NOT called when the connection state changes;
#                 register a callback with "conn" for that task.
#         """
#         self.status = FilterWheelStatus()
#         BaseDevice.__init__(self,
#             name = name,
#             host = host,
#             port = port,
#             callFunc = callFunc,
#         )

#     def setupCmdQueue(self):
#         cmdQueue = CommandQueue(
#             priorityDict = {
#                 "init" : CommandQueue.Immediate,
#                 # all other commands have an equal (default) priority
#             }
#         )
#         return cmdQueue

#     def move(self, position, userCmd=None):
#         """!Move the filter wheel to the wanted position

#         @param[in] position  an integer
#         @param[in] userCmd  a twistedActor.BaseCommand
#         """
#         userCmd = expandUserCmd(userCmd)
#         self.queueDevCmd("move %i"%position, userCmd)
#         return userCmd

#     def home(self, userCmd=None):
#         """!Home the filter wheel

#         @param[in] userCmd  a twistedActor.BaseCommand
#         """
#         userCmd = expandUserCmd(userCmd)
#         self.queueDevCmd("home", userCmd)
#         return userCmd

#     def talk(self, text, userCmd=None):
#         """!Home the filter wheel

#         @param[in] text a string to send to the device
#         @param[in] userCmd  a twistedActor.BaseCommand
#         """
#         userCmd = expandUserCmd(userCmd)
#         self.queueDevCmd(text, userCmd)
#         userCmd.setState(userCmd.Done)
#         return userCmd

#     def parseStatusLine(self, statusLine):
#         # print("%s parseStatusLine(%s)"%(self, statusLine))
#         for keyVal in statusLine.split():
#             if keyVal.startswith("moving="):
#                 self.status.isMoving = keyVal.split("moving=")[-1] == "True"
#             else:
#                 assert keyVal.startswith("position=")
#                 self.status.position = int(keyVal.split("position=")[-1])
#                 # print("%s set postion to %i"%(self, int(keyVal.split("position=")[-1])))
