from __future__ import division, absolute_import

import collections

import RO

from twistedActor import CommandQueue, expandUserCmd, ActorDevice

from .baseDev import BaseDevice

__all__ = ["FilterWheelDevice"]

FilterEnumNameDict = collections.OrderedDict((
    (1, RO.StringUtil.quoteStr("SDSS u")),
    (2, RO.StringUtil.quoteStr("SDSS g")),
    (3, RO.StringUtil.quoteStr("SDSS r")),
    (4, RO.StringUtil.quoteStr("SDSS i")),
    (5, RO.StringUtil.quoteStr("SDSS z")),
    (6, RO.StringUtil.quoteStr("place holder")),
))

class FilterWheelStatus(object):
    def __init__(self):
        self.isMoving = False
        self.position = 0

    def getStatusStr(self):
        # filterNames = "filterNames=?"
        # filterID = "filterID=1"
        # filterName = "filterName=?"

        filterNames = "filterNames=" + ", ".join(FilterEnumNameDict.values())
        filterID = "filterID=%i"%(self.position+1)
        if self.position == 0:
            filterName="?"
        else:
            filterName = "filterName=%s"%(FilterEnumNameDict[self.position])
        return "; ".join([filterNames, filterID, filterName])


class FilterWheelDevice(ActorDevice):
    """!A Mirror Device
    """
    DefaultTimeLim = None # a poor choice, but the best we can do until commands pay attention to predicted duration
    def __init__(self,
        host,
        port,
        name="arcticFilterWheel",
        modelName = "mirror", # hack
    ):
        """!Construct a FilterWheelDevice

        @param[in] host  mirror controller host
        @param[in] port  mirror controller port
        @param[in] modelName  name of mirror controller keyword dictionary; usually "mirror"
        """
        self.status = FilterWheelStatus()
        ActorDevice.__init__(self,
            name=name,
            host=host,
            port=port,
            modelName=modelName,
        )

    def init(self, userCmd=None, timeLim=2, getStatus=True):
        """!Initialize the device and cancel all pending commands

        @param[in] userCmd  user command that tracks this command, if any
        @param[in] timeLim  maximum time before command expires, in sec; None for no limit
        @param[in] getStatus  IGNORED (status is automatically output sometime after stop)
        @return userCmd (a new one if the provided userCmd is None)
        """
        userCmd = expandUserCmd(userCmd)
        self.startCmd(cmdStr="stop", userCmd=userCmd, timeLim=timeLim)
        return userCmd

    def _statusCallback(self, cmd):
        """! When status command is complete, send info to users
        """
        import pdb; pdb.set_trace()
        if cmd.isDone:
            self.writeToUsers("i", self.status.getStatusStr(), cmd)

    def getStatus(self, userCmd=None):
        """!Query the device for status
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.startCmd("status", userCmd=userCmd, callFunc=self._statusCallback)
        # userCmd.addCallback(self._statusCallback)
        return userCmd

    # def startKWForwarding(self):
    #     """!Method to begin keyword forwarding for keywords of interest,
    #     if self.writeToUsers has been added by the actor.
    #     """
    #     def forwardKW(value, isCurrent, keyVar):
    #         """!KeyVar callback on KeyVar objects that the TCC cares about
    #         simply forwards on the keyword with a mirror name prepended
    #         """
    #         # if this is text, don't prepend the mirror name, just forward as is
    #         msgCode = keyVar.reply.header.code if keyVar.reply else "i"
    #         if keyVar.name.lower() == "text":
    #             # only forward if it is a warning or higher
    #             if msgCode in ["e", "w"]:
    #                 mirNameUp = ""
    #                 keyVarNameUp = keyVar.name
    #                 msgStr = "Text=" + "\"" + str(keyVar.valueList[0]) + "\""
    #                 # import pdb; pdb.set_trace()
    #             else:
    #                 # do nothing
    #                 return
    #         else:
    #             # get uppercase name, eg Tert (not tert)
    #             mirNameUp = self.name[0].capitalize() + self.name[1:]
    #             keyVarNameUp = keyVar.name[0].capitalize() + keyVar.name[1:]
    #             # print 'callback value', keyVar, str(value), str(keyVar.valueList)
    #             strValList = []
    #             for value in keyVar.valueList:
    #                 strValList.append(str(value) if value!=None else "NaN")
    #             # prepend name to msg keyword
    #             msgStr = '%s=%s' % (''.join([mirNameUp, keyVarNameUp]), ','.join(strValList))
    #         self.writeToUsers(msgCode=msgCode, msgStr=msgStr)

    #     for kw in tccKWs:
    #         getattr(self.dispatcher.model, kw).addValueCallback(forwardKW, callNow = True)

    def handleReply(self, reply):
        """!Called each time a reply comes through the line
        """
        print "%s.handleReply(reply=%r)" % (self, reply)
        # log.info("%s read %r" % (self, reply))

    # @property
    # def timeLimKeyVar(self):
    #     """!Return a tuple containing the time limit keyvar and index for use in setting automatically
    #     updating time limits
    #     """
    #     return (self.dispatcher.model.state, 4)

    def move(self, position, userCmd=None):
        """!Move the filter wheel to the wanted position

        @param[in] position  an integer
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.startCmd("move %i"%position, userCmd=userCmd)
        return userCmd

    def status(self, userCmd=None):
        """!Get FW status
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.startCmd("status", userCmd=userCmd)
        return userCmd

    def startCmd(self,
        cmdStr,
        callFunc = None,
        userCmd = None,
        timeLim = 0,
        timeLimKeyVar = None,
        timeLimKeyInd = 0,
        abortCmdStr = None,
        keyVars = None,
        showReplies = False,
    ):
        """!Queue or start a new command.

        If timeLimKeyVar not specified, use the state keyword.

        @param[in] cmdStr  the command; no terminating \n wanted
        @param[in] callFunc  callback function: function to call when command succeeds or fails, or None;
            if specified it receives one argument: an opscore.actor.CmdVar object
        @param[in] userCmd  user command that tracks this command, if any
        @param[in] callFunc  a callback function; it receives one argument: a CmdVar object
        @param[in] userCmd  user command that tracks this command, if any
        @param[in] timeLim  maximum time before command expires, in sec; 0 for no limit
        @param[in] timeLimKeyVar  a KeyVar specifying a delta-time by which the command must finish
            this KeyVar must be registered with the message dispatcher.
        @param[in] timeLimKeyInd  the index of the time limit value in timeLimKeyVar; defaults to 0;
            ignored if timeLimKeyVar is None.
        @param[in] abortCmdStr  a command string that will abort the command.
            Sent to the actor if abort is called and if the command is executing.
        @param[in] keyVars  a sequence of 0 or more keyword variables to monitor for this command.
            Any data for those variables that arrives IN RESPONSE TO THIS COMMAND is saved
            and can be retrieved using cmdVar.getKeyVarData or cmdVar.getLastKeyVarData.
        @param[in] showReplies  show all replies as plain text?

        @return devCmd: the device command that was started (and may already have failed)

        @note: if callFunc and userCmd are both specified callFunc is called before userCmd is updated.
        """
        # if not timeLimKeyVar:
        #     timeLimKeyVar, timeLimKeyInd = self.model.state, 3
        return ActorDevice.startCmd(self,
            cmdStr = cmdStr,
            callFunc = callFunc,
            userCmd = userCmd,
            timeLim = timeLim,
            timeLimKeyVar = timeLimKeyVar,
            timeLimKeyInd = timeLimKeyInd,
            abortCmdStr = abortCmdStr,
            keyVars = keyVars,
            showReplies = showReplies,
        )


class FilterWheelDeviceOld(BaseDevice):
    def __init__(self, name, host, port, callFunc=None):
        """!Construct an FilterWheelDevice

        Inputs:
        @param[in] name  name of device
        @param[in] host  host address of Galil controller
        @param[in] port  port of Galil controller
        @param[in] callFunc  function to call when state of device changes;
                note that it is NOT called when the connection state changes;
                register a callback with "conn" for that task.
        """
        self.status = FilterWheelStatus()
        BaseDevice.__init__(self,
            name = name,
            host = host,
            port = port,
            callFunc = callFunc,
        )

    def setupCmdQueue(self):
        cmdQueue = CommandQueue(
            priorityDict = {
                "init" : CommandQueue.Immediate,
                # all other commands have an equal (default) priority
            }
        )
        return cmdQueue

    def move(self, position, userCmd=None):
        """!Move the filter wheel to the wanted position

        @param[in] position  an integer
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd("move %i"%position, userCmd)
        return userCmd

    def home(self, userCmd=None):
        """!Home the filter wheel

        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd("home", userCmd)
        return userCmd

    def talk(self, text, userCmd=None):
        """!Home the filter wheel

        @param[in] text a string to send to the device
        @param[in] userCmd  a twistedActor.BaseCommand
        """
        userCmd = expandUserCmd(userCmd)
        self.queueDevCmd(text, userCmd)
        userCmd.setState(userCmd.Done)
        return userCmd

    def parseStatusLine(self, statusLine):
        # print("%s parseStatusLine(%s)"%(self, statusLine))
        for keyVal in statusLine.split():
            if keyVal.startswith("moving="):
                self.status.isMoving = keyVal.split("moving=")[-1] == "True"
            else:
                assert keyVal.startswith("position=")
                self.status.position = int(keyVal.split("position=")[-1])
                # print("%s set postion to %i"%(self, int(keyVal.split("position=")[-1])))
