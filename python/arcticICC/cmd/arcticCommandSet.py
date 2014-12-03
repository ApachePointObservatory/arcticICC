"""Arctic ICC command definitions
"""
from __future__ import division, absolute_import

from .parse import CommandDefinition, CommandSet
from .parse import ArgumentBase as Arg

__all__ = ["arcticCommandSet"]

#set command
setCmd = CommandDefinition(
    argumentList = [
        Arg(keyword="set",
            unorderedArgumentList = [
                Arg(keyword="window", valueCast=str),
                Arg(keyword="filter", valueCast=str),
                Arg(keyword="temp", valueCast=float),
            ]
        ),
    ]
)


# expose command
commonExposeArgs = [
    Arg(keyword="time", valueCast=float),
    Arg(keyword="basename", valueCast=str, mandatory=False),
    Arg(keyword="comment", valueCast=str, mandatory=False),
]
exposeCmd = CommandDefinition(
        argumentList = [
            Arg(
                keyword = "expose", # main command
                childArgumentList = [
                    Arg(keyword = "object", unorderedArgumentList = commonExposeArgs),
                    Arg(keyword = "flat", unorderedArgumentList = commonExposeArgs),
                    Arg(keyword = "dark", unorderedArgumentList = commonExposeArgs),
                    Arg(keyword = "pause"),
                    Arg(keyword = "resume"),
                    Arg(keyword = "stop"),
                    Arg(keyword = "abort"),
                ]
            )
        ]
    )

# camera command
cameraCmd = CommandDefinition(
    argumentList = [
        Arg(keyword = "camera"),
        Arg(oneOf = ["status", "init"])
        ]
    )

initCmd = CommandDefinition(
    argumentList = [Arg(keyword="init")]
    )

statusCmd = CommandDefinition(
    argumentList = [Arg(keyword="status")]
    )

arcticCommandSet = CommandSet(
    cmdDefinitionList=[
        setCmd,
        exposeCmd,
        cameraCmd,
        initCmd,
        statusCmd
    ]
    )