# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Validation framework"""
import abc


class BaseValidator(abc.ABC):
    """Validators are classes that is used to validate according to specific policies and stems from this class."""
    pass