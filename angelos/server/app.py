"""Module docstring."""
from ..ioc import ContainerAware


class Application(ContainerAware):
    def _initialize(self):
        pass

    def _finalize(self):
        pass

    def run(self):
        pass
