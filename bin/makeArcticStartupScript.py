#!/usr/bin/env python2
from __future__ import division, absolute_import
"""Make a arcticICC startup script for a specified telescope

$ setup arcticICC
$ sudo makeArcticStartupScript.py >/usr/local/bin/arcticICC
$ sudo chmod +x /usr/local/bin/arcticICC
"""
import syslog

from twistedActor import makeStartupScript

import arcticICC

if __name__ == '__main__':
    startupScript = makeStartupScript(
        actorName="arcticICC",
        pkgName="arcticICC",
        binScript="runArcticICC.py",
        userPort=arcticICC.UserPort,
        facility=syslog.LOG_LOCAL1,

    )
    print startupScript
