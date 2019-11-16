#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
from libangelos.ioc import Container, ContainerAware


class Stub(ContainerAware):
    """Application Stub."""

    def __init__(self):
        """Initialize class."""
        ContainerAware.__init__(self, self.build_config())

    def build_config(self) -> Container:
        """Implement method that returns a custom configuration."""
        raise NotImplementedError()
