from coverage.plugin import CoveragePlugin, FileTracer, FileReporter  # requires coverage.py 4.0+


class TestTracer(FileTracer):
    def __init__(self, filename):
        FileTracer.__init__(self)
        self._filename = filename
        # print("FILENAME", filename)

    def source_filename(self):
        if self._filename.endswith(".pyx"):
            print("\033[92m", self._filename, "\033[0m")
        return self._filename


class TestReporter(FileReporter):
    def __init__(self, filename):
        FileReporter.__init__(self, filename)
        # print("FILENAME", filename)

    def lines(self):
        return set()


class TestPlugin(CoveragePlugin):

    def file_tracer(self, filename):
        return TestTracer(filename)

    def file_reporter(self, filename):
        return TestReporter(filename)


def coverage_init(reg, options):
    plugin = TestPlugin()
    reg.add_configurer(plugin)
    reg.add_file_tracer(plugin)
