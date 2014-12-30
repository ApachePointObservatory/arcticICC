from __future__ import division, absolute_import

import pyparsing as pp

import RO.Alg.MatchList as MatchList
from RO.StringUtil import unquoteStr

"""@todo:
pretty printing __str__, __repr__
help strings, self documentation
append parent/top command info/name to individual arguments?
support comments?
add qualifier indicator
"""

class CommandDefinitionError(Exception):
    pass

class ParseError(Exception):
    pass

class CommonParseItems(object):
    def __init__(self):
        """! Reusable pyparsing pieces.
        """
        self.ppFloat = self.floatDef()
        self.ppQuotedString = self.quotedStringDef()
        self.ppWord = self.wordDef()

        # keyword
        # self.keyword = pp.Word(pp.alphas + pp.alphanums, pp.alphas + '_:.' + pp.alphanums)

        # self.value = pp.quotedString | word | number
        # self.valueList = pp.delimitedList(self.value)
        # self.keywordValue = self.keyword + pp.Literal("=").suppress() + self.value
        # # allow brackets and parentheses optionally surrounding keyword=[list]
        # self.keywordValueList = self.keyword + pp.Literal("=").suppress() + pp.Optional(pp.ofOf(["(", "["])).suppress() + self.valueList + pp.Optional(pp.ofOf([")", "]"])).suppress()
        # self.listKeywordValues = pp.delimitedList(word + pp.Literal("=").suppress() + self.value) # thinking set weather bhah=2,foo=bar

    def floatDef(self):
        # set up a float, allow scientific notation
        point = pp.Literal( "." )
        e     = pp.CaselessLiteral( "E" )
        ppFloat = pp.Combine( pp.Word( "+-"+pp.nums, pp.nums ) +
            pp.Optional( point + pp.Optional( pp.Word( pp.nums ) ) ) +
            pp.Optional( e + pp.Word( "+-"+pp.nums, pp.nums ) ) )
        def onParse(token):
            return float(token[0])
        ppFloat.setParseAction(onParse)
        return ppFloat

    def quotedStrDef(self):
        def onParse(token):
            return unquoteStr(token[0])
        return pp.quotedString.setParseAction(onParse)

    def wordDef(self):
        return pp.Word(pp.alphas + pp.alphanums, pp.alphas + '_:.' + pp.alphanums)

    def keywordDef(self, matchList):
        """matchList: A RO MatchList object
        """
        def onParse(tolken):
            kw = str(tolken[0])
            # see if keyword is in list, else raise a parse error
            try:
                fullKW = matchList.getUniqueMatch(kw)
            except ValueError:
                raise ParseError("%s not uniquely defined in %s"%(kw, str(matchList.valueList)))
            return fullKW
        return self.ppWord.setParseAction(onParse)




class ParsedCommand(object):

    def __init__(self, cmdName):
        self.cmdName = cmdName
        self.subCommand = None

    def setSubCommand(self, parsedCmd):
        self.subCommand = parsedCmd

class ParsedArgument(object):
    pass


class CommandSet(object):
    def __init__(self, commandList):
        """! Generate a command set
        @param[in] commandList: a list of Command objects
        """
        # turn list of commands into a dictionary
        self.commandDict = {}
        for command in commandList:
            self.commandDict[command.keyword] = command
        self.commandMatchList = MatchList(valueList = self.commandDict.keys())

    def getCommand(self, cmdName):
        """! Get a command in the set from a command name. Name may be abbreviated
        as long as it is unique to the command set.
        """
        return self.commandDict[self.commandMatchList.getUniqueMatch(cmdName)]

    def parse(self, cmdStr):
        """! Parse a command string.

        @param[in] cmdStr, the command string to be parsed
        @return ParsedCommand object
        """
        # use pyparsing instead? any advantage?
        # determine which command we are parsing
        cmdName, cmdArgs = cmdStr.split(" ", 1)
        cmdName = cmdName.strip()
        cmdArgs = cmdArgs.strip()
        cmdObj = self.getCommand(cmdName) # cmdName abbreviations allowed!
        return cmdObj.parse(cmdArgs)


# class ArgumentBase(object):
#     def __init__(self,
#         keyword=None,
#         valueCast=None,
#         unorderedArgumentList=None, # order doesn't matter, must be keyword-like
#         orderedArgumentList=None, # order matters
#         oneOf=None, # only one
#         oneOrMoreOf=None,
#         mandatory=True,
#         negatable=False
#         ):
#         self.keyword=keyword,
#         self.valueCast=valueCast,
#         if unorderedArgumentList:
#             # verify a keyword is supplied for all
#             for arg in unorderedArgumentList:
#                 if arg.keyword is None:
#                     raise CommandDefinitionError("%s must have a defined keyword to be valid in an unorderedArgumentList!"%str(arg))
#         self.unorderedArgumentDict = {}
#         for arg in unorderedArgumentList:
#             self.unorderedArgumentDict[arg.keyword] = arg
#         # compile a unique identifier list for unorderedArguments
#         self.unorderedArgMatchList = MatchList(valueList = self.unorderedArgumentDict.keys())
#         self.orderedArgumentList=orderedArgumentList,
#         self.oneOf=oneOf, # only one
#         self.oneOrMoreOf=oneOrMoreOf,
#         self.mandatory=mandatory,
#         self.negatable=negatable

class ArgumentBase(object):

    def __init__(self):
        pass

    @property
    def parserElement(self):
        """! must return a pyparsing ParserElement
        """
        raise NotImplementedError

    def parseAction(self):
        """! set this on self.parserElement
        """
        raise NotImplementedError

class KeywordArgument(ArgumentBase):
    pass


class Command(ArgumentBase):
    def __init__(self,
        commandName,
        subCommandList=None,
        orderedArgumentList=None,
        unorderedArgumentList=None
        ):
        """Command may only be a keyword with arguments or subcommands, no value.
        """
        if subCommandList and orderedArgumentList:
            # unorderedArguments are allowed anywhere (eg qualifiers)
            raise CommandDefinitionError("May not specify subCommandList AND orderedArgumentList")
        if subCommandList:
            self.subCommandSet = CommandSet(subCommandList)
        else:
            self.subCommandSet = None
        ArgumentBase.__init__(self,
            keyword=commandName,
            orderedArgumentList = orderedArgumentList,
            unorderedArgumentList = unorderedArgumentList,
            )

    def parse(self, cmdString):
        """! parse a raw command string
        @param[in] cmdString, string to be parsed.
        """
        # first, look for subcommands.
        parsedCommand = ParsedCommand(self.keyword)
        if self.subCommandSet:
            # parse the remaining argument string just like a full command
            parsedCommand.setSubCommand(self.subCommandSet.parse(cmdString))
        else:
            # look for unordered arguments of type keyword=value in order
            pass


class SubCommand(ArgumentBase):
    def __init__(self,
        subCommandName,
        valueCast=None,
        unorderedArgumentList=None,
        orderedArgumentList=None,
        ):
        """note subcommand may also have a value!
        """
        ArgumentBase.__init__(self,
            keyword=subCommandName,
            valueCast=valueCast,
            unorderedArgumentList=unorderedArgumentList, # order doesn't matter, must be keyword-like
            orderedArgumentList=orderedArgumentList, # order matters
            )

class ArgumentSet(object):
    pass

class FloatingArgumentSet(ArgumentSet):
    pass

class OrderedArgumentSet(ArgumentSet):
    """Searched.
    """
    pass















