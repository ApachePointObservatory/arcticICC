"""Arctic ICC command definitions
"""
from __future__ import division, absolute_import

from .parse import Command, CommandSet, KeywordValue, Float, String, Int, UniqueMatch, RestOfLineString

__all__ = ["arcticCommandSet"]

optionalExposeArgs = [
    KeywordValue(
        keyword="basename",
        value=String(helpStr="string help"),
        isMandatory=False,
        helpStr="basename help"
    ),
    KeywordValue(
        keyword="comment",
        value=String(helpStr="comment help"),
        isMandatory=False,
        helpStr="comment help"
    ),
]

timeArg = [
    KeywordValue(
        keyword="time",
        value=Float(helpStr="float help"),
        helpStr="time help"
    )
]

arcticCommandSet = CommandSet(
    commandList = [
        # set command
        Command(
            commandName = "set",
            floatingArguments = [
                KeywordValue(
                    keyword="bin",
                    value=Int(nElements=(1,2), helpStr="an int"),
                    isMandatory=False,
                    helpStr="bin help"
                    ),
                KeywordValue(
                    keyword="window",
                    value=String(nElements=(1,4), helpStr="window list value help"), # must be string to support "full"
                    isMandatory=False,
                    helpStr="window help"
                    ),
                KeywordValue(
                    keyword="amps",
                    value=UniqueMatch(["ll", "quad", "auto"], helpStr="unique match"),
                    isMandatory=False,
                    helpStr="amps help"
                    ),
                KeywordValue(
                    keyword="readoutRate",
                    value=UniqueMatch(["slow", "medium", "fast"], helpStr="unique match"),
                    isMandatory=False,
                    helpStr="readoutRate help"
                    ),
                KeywordValue(
                    keyword="filter",
                    value=String(helpStr="a name or number"),
                    isMandatory=False,
                    helpStr="filter help"
                    ),
                KeywordValue(
                    keyword="temp",
                    value=Float(helpStr="temp set point"),
                    isMandatory=False,
                    helpStr="temp help"
                    ),
            ],
            helpStr="set command help"
        ),
        Command(
            commandName = "expose",
            subCommandList = [
                Command(
                    commandName="object",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="object subcommand help"
                ),
                Command(
                    commandName="flat",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="flat subcommand help"
                ),
                Command(
                    commandName="dark",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="dark subcommand help"
                ),
                Command(
                    commandName="bias",
                    floatingArguments = optionalExposeArgs,
                    helpStr="bias subcommand help"
                ),
                Command(
                    commandName="pause",
                    helpStr="pause subcommand help"
                ),
                Command(
                    commandName="resume",
                    helpStr="resume subcommand help"
                ),
                Command(
                    commandName="stop",
                    helpStr="stop subcommand help"
                ),
                Command(
                    commandName="abort",
                    helpStr="abort subcommand help"
                ),
            ]
        ),
        Command(
            commandName = "camera",
            positionalArguments = [UniqueMatch(["status", "init"], helpStr="unique match help")],
            helpStr = "camera help"
        ),
        Command(
            commandName = "filter",
            subCommandList = [
                Command(
                    commandName = "status",
                    helpStr = "subcommand status help"
                ),
                Command(
                    commandName = "init",
                    helpStr = "subcommand init help"
                ),
                Command(
                    commandName = "home",
                    helpStr = "subcommand home help"
                ),
                Command(
                    commandName = "talk",
                    positionalArguments = [RestOfLineString(helpStr="text to send to filter")],
                    helpStr = "subcommand talk help"
                ),
            ]
        ),
        Command(
            commandName = "init",
            helpStr = "init help"
        ),
        Command(
            commandName = "status",
            helpStr = "status help"
        ),
        Command(
            commandName = "ping",
            helpStr = "show alive"
        ),
    ]
)
