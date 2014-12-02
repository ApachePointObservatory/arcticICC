from __future__ import division, absolute_import

import pyparsing

class CommandParser(object):
    def __init__(self, cmdList):
        """! Command parser
        @param[in] cmdList: a list of CommandDefinition objects
        """
        pass

    def defineGrammar(self):
        """! Setup pyparsing grammer
        """
        pass

    def parse(self, cmdString):
        """! Parse a command string
        @param[in] cmdString: a command string
        @return ParsedCommand object
        """
        pass

class ParsedCommand(object):
    pass


class CommandDefinition(object):
    def __init__(self,
        cmdName,
        mandatoryArgumentList,
        optionalArguementList,
        floatingArgumentList,
        floatingArgumentIndicator = "/",
    ):
        """! Define a command
        @param[in] cmdName: name of command, first word of a command string.
        @param[in] mandatoryArgumentList: a list of ArgumentDefinition objects, these must be specified for a command to be vaild, order counts
        @param[in] optionalArgumentList: a list of ArgumentDefinition objects, these may be specified after the mandatoryArgumentList, order counts
        @param[in] floatingArgumentList: a list of ArgumentDefinition objects, these may be specified anywhere in the command
        @param[in] floatingArgumentIndicator: a character immediately preceeding and thus indicating that a floating argument follows, order does not matter.
        """
        pass

class ArgumentDefinition(object):
    pass









