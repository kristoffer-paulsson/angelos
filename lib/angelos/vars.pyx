# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Environment and configuration variables for the server.

The difference between environmental and configurational variables are how they
are being used. Environmental variables are globally available values that
might effect the runtime of the software. Configurational variables in
particular are used to configure services available from the IoC container.
"""

from libangelos.const import Const

"""Environment default values."""
ENV_DEFAULT = {}

"""Environment immutable values."""
ENV_IMMUTABLE = {"name": "logo"}

"""Configuration default values"""
CONFIG_DEFAULT = {"ports": {"nodes": 3, "hosts": 4, "clients": 5}}

"""Configuration immutable values"""
CONFIG_IMMUTABLE = {
    "state": [
        {"name": "running"},
        {"name": "boot", "blocking": ("serving",), "depends": ("running",)},
        {"name": "serving", "depends": ("running",), "switches": ("boot",)},
        {"name": "nodes", "depends": ("serving",)},
        {"name": "hosts", "depends": ("serving",)},
        {"name": "clients", "depends": ("serving",)},
    ],
    "logger": {
        "version": 1,
        "formatters": {
            "default": {
                "format": "%(asctime)s %(name)s:%(levelname)s %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
            "console": {"format": "%(levelname)s %(message)s"},
        },
        "filters": {"default": {"name": ""}},
        "handlers": {
            "default": {
                "class": "logging.FileHandler",
                "filename": "angelos.log",
                "mode": "a+",
                "level": "INFO",
                "formatter": "default",
                "filters": [],
            },
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "level": "ERROR",
                "formatter": "console",
                "filters": [],
            },
        },
        "loggers": {
            Const.LOG_ERR: {  # LOG_ERR is used to log system errors
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_APP: {  # LOG_APP is used to log system events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_BIZ: {  # LOG_BIZ is used to log business events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            "asyncio": {  # 'asyncio' is used to log business events
                "level": "WARNING",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
        },
        "root": {
            "level": "DEBUG",
            "filters": [],
            "handlers": ["console", "default"],
        },
        # 'incrementel': False,
        "disable_existing_loggings": True,
    },
    "terminal": {
        "prompt": "Angelos 0.1dX > ",
        "message": "Ἄγγελος safe messenging server",
    },
}

SERVER_RSA_PRIVATE = """\
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAr35jVWyG3gjaQ735h8sBuJiJr/dWi9CfuDl0bdYlIaz1qUMa
pVlcPVEjH/ukVTOi8dme0dqPnO7za00/4BVrtsKqMXDhsrE+RhC6d8QWsk+Rf5Ym
c5Qjmhio0aqC7gDmDAT0bQytVM2seOVg22dqXZiO00pIB9lM/KeLJxLczQeS8gfD
iBdZI1Kb5ul90H6v0lklb6DyAUostiHdVPoFOAlFwgKXzgBqWMHj4fYApeNDSEuE
yYDKzxkTqU5Hgs+4dGBnjrBfhfLjM21GVBTgPXHr66IKtZ0FCEPdT+xGmdU6ni70
6SZ78NB+H49CYe8U4vJ007fjKsRPtvoFcdLzMQIDAQABAoIBAEvfSrbt+skX7rWG
9tD8tbvHRw/q0WIVSlhtjqbGBLuweW06c9S086oW4Ca9tuiXMIV7Xqy/34Mr09W6
SjlpSW50bvx9HzcQZioIpXWOM3nX6MHOesVRcKr4qlQrcfvQK6VapwpWhsG5Qi3q
jZuN9HCOuoEjBk1OZ3h8Py8fepKxUW1CQ5mEeub16Wwg17hltQliwLLfHUCt/Mu5
/u91IMiJGZYPZTyPFNiP42hNKz15ldRbwOgu5pA+BtyZ+DgfjqgZ2lY+eNucucZW
Cn9SwX1RFmtI3p8HHYHFDpfPtY2G5tI1oiV/bUbI/PQqaDRpyWliG+TD+5rrz1eQ
xpV8tHkCgYEA6ezQKOyoWjLO5/lkErlui9AOqIBW5hRYPh+2wv2By7LK7LDj0TdE
DKBjcYO31/LU2H5Ms+WI4T2hH5bBJZnxrTOCMgJxCuLX0wHn+eo/6s7xzpnwG77R
+ygGfU3wwdGhhAJFHOHS2uYLUt7LvMWgHLweB3Lb6tSLsAZqEYrEeQcCgYEAwA37
6RHdXVfVEb9r+hYOaTnSjjs0JPkBNL0QNDkcdlRiBG8O4V6EQ3xMDTWrirTIma5/
EQpHZXJrL5cEIphwZ71Up7bZeisIgr+piio2rMC259idAlFveOQaBsmZ0a1vnN35
TwdLXS/LJwzfPPqrwt7J05yHLneC/4oboj26PAcCgYEAksaNQfBkHdxdaL5ZpUoG
a+GLIP0OCWVgjPJXOXfZFhfELck72M1FfGqymsob83qhRInS1NnEDhgeXfS4kkBK
nPOB0KEpjrwQ0YwTowLxQgLBRHHgb3hGxsExeTQLSYGgR3UpKlsjc0f+eOvkiDi0
IvOCIAhYprrgPv13VjRs3McCgYAPf9FpsNhllRYL9Z/YMfl9wn3cnqiJp1LSl8N8
A3PplMvIQdI4m/EepSRaGI+8hPR/epakoGi8pixCTfS2egjwRlZTpq0Mb/ai3qbn
EJsS/AaG1XNuYXYWkooLLC/uvQl55mwdVaBeZ+IER8SoXi6IboRpQIOkW17GErZC
NKsX9wKBgQCiDMUwyHB294f08/s1HHHc8taNclgHLFREKN7DVvTAxeWyfcOlYd9O
8Htbs0Nwy4yfaP6d76Uw2YtWu3InRyJfea6vPag6/nelnu7p040B8zLCXm/kB/EP
wubsVeAiD5NWk6Mb+pwT2hwybTRoWCdA+B0nZtocEGmQRib/jW6BZA==
-----END RSA PRIVATE KEY-----
"""

SERVER_RSA_PUBLIC = """ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvfmNVbIbeCNpDvfm\
HywG4mImv91aL0J+4OXRt1iUhrPWpQxqlWVw9USMf+6RVM6Lx2Z7R2o+c7vNrTT/gFWu2wqoxcOGys\
T5GELp3xBayT5F/liZzlCOaGKjRqoLuAOYMBPRtDK1Uzax45WDbZ2pdmI7TSkgH2Uz8p4snEtzNB5L\
yB8OIF1kjUpvm6X3Qfq/SWSVvoPIBSiy2Id1U+gU4CUXCApfOAGpYwePh9gCl40NIS4TJgMrPGROpT\
keCz7h0YGeOsF+F8uMzbUZUFOA9cevrogq1nQUIQ91P7EaZ1TqeLvTpJnvw0H4fj0Jh7xTi8nTTt+M\
qxE+2+gVx0vMx"""
