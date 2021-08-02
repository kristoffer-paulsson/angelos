import glob
import os
import re
import sys
from collections import defaultdict

from coverage.files import canonical_filename
from coverage.plugin import CoveragePlugin, FileTracer, FileReporter


class Tracer(FileTracer):

    cache = dict()

    def __init__(self, filename, file, prefixes):
        FileTracer.__init__(self)
        self._filename = filename
        self._file = file
        self._prefixes = prefixes

    def source_filename(self):
        return self._filename

    def has_dynamic_source_filename(self):
        return self._file

    def dynamic_source_filename(self, filename, frame):
        current = frame.f_code.co_filename

        if current in self.cache:
            return self.cache[current]

        for prefix in self._prefixes:
            origin = prefix + current[3:]
            if os.path.isfile(origin):
                self.cache[current] = origin
                return origin

        raise OSError("didn't find real path for: {}".format(current))


class Reporter(FileReporter):
    def __init__(self, filename, sources):
        FileReporter.__init__(self, filename)
        self._sources = sources
        self._cfile = None
        self._executable = set()
        self._excluded = set()

        for prefix in self._sources:
            if filename.startswith(prefix):
                prefix_len = len(prefix)
                cfile = filename[:prefix_len-3] + "build/" + filename[prefix_len-3:-4] + ".c"
                if os.path.isfile(cfile):
                    self._cfile = cfile
                break

        if not self._cfile:
            with open(self.filename, "rb") as f:
                count = 0
                for _ in f:
                    count += 1
                    self._executable.add(count)
        else:
            self._executable = self._parse_cfile_lines(self._cfile)

    def lines(self):
        return self._executable

    def excluded_lines(self):
        return self._excluded

    def _parse_cfile_lines(self, c_file):
        """
        Parse a C file and extract all source file lines that generated executable code.
        """
        # LICENSE: https://github.com/cython/cython/blob/master/LICENSE.txt
        # Modified by Kristoffer Paulsson 2021-08-02 to fit this project with multiple namespace packages.
        # Multiple lines has become unnecessary and been removed, also unnecessary complexity.
        match_source_path_line = re.compile(r' */[*] +"(.*)":([0-9]+)$').match
        match_current_code_line = re.compile(r' *[*] (.*) # <<<<<<+$').match
        match_comment_end = re.compile(r' *[*]/$').match
        match_trace_line = re.compile(r' *__Pyx_TraceLine\(([0-9]+),').match
        not_executable = re.compile(
            r'\s*c(?:type)?def\s+'
            r'(?:(?:public|external)\s+)?'
            r'(?:struct|union|enum|class)'
            r'(\s+[^:]+|)\s*:'
        ).match

        code_lines = set()
        executable = set()
        current_filename = None

        with open(c_file) as lines:
            lines = iter(lines)
            for line in lines:
                match = match_source_path_line(line)
                if not match:
                    if '__Pyx_TraceLine(' in line and current_filename is not None:
                        trace_line = match_trace_line(line)
                        if trace_line:
                            executable.add(int(trace_line.group(1)))
                    continue
                filename, lineno = match.groups()
                current_filename = filename
                lineno = int(lineno)
                for comment_line in lines:
                    match = match_current_code_line(comment_line)
                    if match:
                        code_line = match.group(1).rstrip()
                        if not_executable(code_line):
                            break
                        code_lines.add(lineno)
                        break
                    elif match_comment_end(comment_line):
                        # unexpected comment format - false positive?
                        break

        # Remove lines that generated code but are not traceable.
        dead_lines = set(code_lines).difference(executable)
        for lineno in dead_lines:
            code_lines.remove(lineno)
        return code_lines


class Coverage(CoveragePlugin):

    _sources = list()

    def file_tracer(self, filename):
        return Tracer(filename, filename.startswith(self._sources) and filename.endswith((".pyx", ".pxd")), self._sources)

    def file_reporter(self, filename):
        return Reporter(filename, self._sources)

    def configure(self, config):
        sources = config.get_option("run:source") or list()
        sources += glob.glob(os.getcwd() + "/src")
        sources += glob.glob(os.getcwd() + "/angelos-*/src")
        sources = set(sources)
        self._sources = tuple(sources)
        config.set_option("run:source", list(sources))

    def find_executable_files(self, src_dir):
        map = set()
        cache = dict()

        for exe in glob.glob(src_dir + "/**", recursive=True):
            if exe.endswith((".py", ".pyx", ".pxd")):
                map.add(exe)
            if exe.endswith((".pyx", ".pxd")):
                key = exe[exe.rfind("src"):]
                if key in cache:
                    raise OSError("Path already in cache: {}".format(key))
                cache[key] = exe
        Tracer.cache = cache

        return list(map)


def coverage_init(reg, options):
    plugin = Coverage()
    reg.add_configurer(plugin)
    reg.add_file_tracer(plugin)