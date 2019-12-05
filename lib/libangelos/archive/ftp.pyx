# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""FTP."""
from ..const import Const
from .storage import StorageFacadeExtension


class FtpStorage(StorageFacadeExtension):
    ATTRIBUTE = ("ftp",)
    CONCEAL = (Const.CNL_FTP,)
    USEFLAG = (Const.A_USE_FTP,)