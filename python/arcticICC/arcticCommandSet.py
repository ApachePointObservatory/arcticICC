"""Arctic ICC command definitions
"""
from __future__ import division, absolute_import

from twistedActor.parse import Command, CommandSet, KeywordValue, Float, String, Int, UniqueMatch, RestOfLineString

__all__ = ["arcticCommandSet"]

optionalExposeArgs = [
    KeywordValue(
        keyword="basename",
        value=String(),
        isMandatory=False,
        helpStr="Specify a full path including name to where the image will be saved.  If not supplied image will be auto-named and saved in ~/images/ on arctic-icc"
    ),
    KeywordValue(
        keyword="comment",
        value=String(),
        isMandatory=False,
        helpStr="IF SUPPLIED THIS ARGUMENT IS IGNORED! Comments are written via the arcticExpose actor.  This is vistigial but necessary because the arcticExpose actor passes this argument along to the arcticICC!"
    ),
]

timeArg = [
    KeywordValue(
        keyword="time",
        value=Float(),
        helpStr="exposure time"
    )
]

arcticCommandSet = CommandSet(
    actorName = "ARCTIC",
    commandList = [
        # set command
        Command(
            commandName = "set",
            helpStr="configure settings for the camera and/or filter wheel",
            floatingArguments = [
                KeywordValue(
                    keyword="bin",
                    value=Int(nElements=(1,2)),
                    isMandatory=False,
                    helpStr="Specify 1 or 2 integers corresponding to column bin factor and row bin factor, respectively.  If only one integer is supplied both bin factors are set equal to this value."
                    ),
                KeywordValue(
                    keyword="window",
                    value=String(nElements=(1,4), repString="begx, begy, width, height | full"), # must be string to support "full"
                    isMandatory=False,
                    helpStr="Specify either 'full' or 4 comma separated integers corresponding to binned pixels defining the window: start x, start y, width, height"
                    ),
                KeywordValue(
                    keyword="amps",
                    value=UniqueMatch(["LL", "UL", "UR", "LR", "Quad", "Auto"]),
                    isMandatory=False,
                    helpStr="Choose which amplifier to read from.  Quad will simultaneously read from all 4.  Note Quad readout mode is only valid for a full CCD window.  Auto will default to Quad if the CCD window is full else LL. "
                    ),
                KeywordValue(
                    keyword="readoutRate",
                    value=UniqueMatch(["Slow", "Medium", "Fast"]),
                    isMandatory=False,
                    helpStr="Choose a readout rate"
                    ),
                KeywordValue(
                    keyword="filter",
                    value=Int(),
                    isMandatory=False,
                    helpStr="Set the filter wheel position. Specify an integer, 1-6 are valid."
                    ),
            ],
        ),
        Command(
            commandName = "expose",
            help = "Take and exposure.",
            subCommandList = [
                Command(
                    commandName="Object",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="Take an Object exposure."
                ),
                Command(
                    commandName="Flat",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="Take a Flat exposure"
                ),
                Command(
                    commandName="Dark",
                    floatingArguments = timeArg + optionalExposeArgs,
                    helpStr="Take a Dark"
                ),
                Command(
                    commandName="Bias",
                    floatingArguments = optionalExposeArgs,
                    helpStr="Take a Bias."
                ),
                Command(
                    commandName="pause",
                    helpStr="Pause the currently active exposure"
                ),
                Command(
                    commandName="resume",
                    helpStr="Resume a paused exposure"
                ),
                Command(
                    commandName="stop",
                    helpStr="Stop a currently active exposure.  Readout the data and save it."
                ),
                Command(
                    commandName="abort",
                    helpStr="Abort a currently active exposure. WARNING: Data is discarded."
                ),
            ]
        ),
        Command(
            commandName = "camera",
            helpStr = "Initialize the camera, or ask for status",
            positionalArguments = [UniqueMatch(["status", "initialize"], helpStr="Pick either status or initialize")],
        ),
        Command(
            commandName = "filter",
            helpStr = "Send various filter wheel related commands.",
            subCommandList = [
                Command(
                    commandName = "status",
                    helpStr = "Query filter wheel for status.",
                ),
                Command(
                    commandName = "initialize",
                    helpStr = "Initialize the filter wheel.  Automatically try to connect first if disconnected.",
                ),
                Command(
                    commandName = "connect",
                    helpStr = "Connect to the filter wheel device.",
                ),
                Command(
                    commandName = "disconnect",
                    helpStr = "Disconnect from the filter wheel device.",
                ),
                Command(
                    commandName = "home",
                    helpStr = "Home the filter wheel.",
                ),
                Command(
                    commandName = "talk",
                    positionalArguments = [RestOfLineString(helpStr="text to send to filter")],
                    helpStr = "Send raw text to the filter wheel device.",
                ),
            ]
        ),
        Command(
            commandName = "initialize",
            helpStr = "Initialize camera and filter wheel device.  Attempt to connect first if disconnected.",
        ),
        Command(
            commandName = "status",
            helpStr = "Query camera and filter wheel device for status.",
        ),
        Command(
            commandName = "connDev",
            helpStr = "connect all device(s)",
        ),
        Command(
            commandName = "disconnDev",
            helpStr = "disconnect all device(s)",
        ),
        Command(
            commandName = "ping",
            helpStr = "show alive",
        ),
    ]
)
