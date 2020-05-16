# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Archive utility."""

import datetime
import fcntl
import hashlib
import math
import os
import struct
import time
import uuid
from abc import ABC, abstractmethod
from io import RawIOBase, SEEK_SET, SEEK_END, SEEK_CUR
from pathlib import PurePath
from typing import Union

import libnacl.secret
from bplustree.tree import BPlusTree
from bplustree.serializer import UUIDSerializer
from libangelos.error import Error
from libangelos.utils import Util