"""Arctic ICC command definitions
"""
from __future__ import division, absolute_import

from .parse import Command, CommandSet, Argument, SubCommand

__all__ = ["arcticCommandSet"]

#set command
setCmd = Command(
    commandName = "set",
    unorderedArgumentList = [
        Argument(keyword="window", valueCast=str),
        Argument(keyword="filter", valueCast=str),
        Argument(keyword="temp", valueCast=float),
    ]
)

# expose command
sharedExposeArgs = [
    Argument(keyword="time", valueCast=float),
    Argument(keyword="basename", valueCast=str, mandatory=False),
    Argument(keyword="comment", valueCast=str, mandatory=False),
]

exposeCmd = Command(
    commandName = "expose",
    subCommandList = [
        SubCommand(subCommandName = "object", unorderedArgumentList = sharedExposeArgs),
        SubCommand(subCommandName = "flat", unorderedArgumentList = sharedExposeArgs),
        SubCommand(subCommandName = "dark", unorderedArgumentList = sharedExposeArgs),
        SubCommand(subCommandName = "pause"),
        SubCommand(subCommandName = "resume"),
        SubCommand(subCommandName = "stop"),
        SubCommand(subCommandName = "abort"),
    ]
)

# camera command
cameraCmd = Command(
    commandName = "camera",
    orderedArgumentList = [Argument(oneOf = ["status", "init"])]
)

initCmd = Command(commandName = "init")

statusCmd = Command(commandName = "status")

arcticCommandSet = CommandSet(
    commandList=[
        setCmd,
        exposeCmd,
        cameraCmd,
        initCmd,
        statusCmd
    ]
)