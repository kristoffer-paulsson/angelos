import threading
import time
import sys
from .utils import Utils
from .common import logger
from .ioc import Container, Service

"""
The task.py module containes classes needed to manage multithreading and
running tasks within the application.
"""


class Signal:
    """
    Signal class is used by the TaskGroup and the Tasks to communicate with the
    each other.
    """

    def __init__(self, halt, run):
        """
        halt    threading.Event signaling halt to all the Task threads
        run        threading.Event signaling pause/resume to all Task threads
        """
        Utils.is_type(halt, threading.Event)
        Utils.is_type(run, threading.Event)

        self.__tasks = {}
        self.__ids = {}

        self.__run = run
        self.__halt = halt

    def halt(self):
        """
        Returns the state of the halt signal
        """
        return self.__halt.is_set()

    def pause(self):
        """
        Will make calling thread pause until resume signal
        """
        start_time = time.time()
        self.__run.wait()
        return time.time() - start_time

    def is_paused(self):
        return not self.__run.is_set()


class Message:
    def __init__(self, receiver, message='', data={}):
        Utils.is_type(receiver, str)
        Utils.is_type(message, str)
        Utils.is_type(data, dict)

        self.__receiver = receiver
        self.__message = Message
        self.__data = data
        self.__sender = None

    def receiveer(self):
        pass

    def message(self):
        pass

    def data(self):
        pass

    def sender(self):
        pass


class Monitor:
    def __init__(self):
        self.__idle = 0.0
        self.__sleep = 0.0
        self.__begin = None
        self.__end = None
        self.__state = None
        self.__sequence = [.0, .0, .0, .0, .0, .0, .0, .0, .0, .0]
        self.__heartbeat = 0.0

    def time(self):
        return time.time()

    def heartbeat(self, hb=None):
        if isinstance(hb, float):
            self.__heartbeat = hb

        return self.__heartbeat

    def begin(self):
        self.__start = time.time()

    def end(self):
        self.__end = time.time()

    def state(self, state=None):
        Utils.is_type(state, (str, type(None)))

        if state is not None:
            self.__state = state

        return self.__state

    def idle(self, time):
        Utils.is_type(time, (int, float))

        self.__idle += time

    def sleep(self, time):
        Utils.is_type(time, (int, float))

        self.__sleep += time

    def sequence(self, seq):
        Utils.is_type(seq, float)

        self.__sequence.pop(0)
        self.__sequence.append(seq)

    def performance(self):
        q = 0
        for x in self.__sequence:
            q += x
        q = q / 10

        u = 0
        if self.__start is not None:
            if self.__end is not None:
                u = self.__end - self.__start
            else:
                u = self.time() - self.__start

        # State
        # Sequence
        # Uptime
        # Idle
        # Sleep
        # Heartbeat
        return [self.__state, q, u, self.__idle,
                self.__sleep, self.__heartbeat]


class Task:
    """
    Task class is a wrapper for threads. The task keeps track of signals and
    contains _initialize(), _finalize() and run() methods. In order to
    implement a task, Task should be subclassed and work() implemented.
    """

    STATE_READY = 'ready'
    STATE_RUNNING = 'running'
    STATE_IDLE = 'idle'
    STATE_PAUSED = 'paused'
    STATE_DONE = 'done'
    STATE_CRASHED = 'error'

    def __init__(self, name, sig):
        """
        name     A string with the Task name
        sig        The Signal class instance to listen too
        config    A dictionary with config values
        """
        Utils.is_type(name, str)
        Utils.is_type(sig, Signal)

        self.__name = name
        self.__sig = sig
        self.__args = {}
        self.__done = False
        self.__idle = 0
        self.m = Monitor()
        self.m.state(Task.STATE_READY)

    def name(self):
        """
        Returns task name.
        """
        return self.__name

    def args(self):
        """
        Returns initiated config values dictionary.
        """
        return self.__args

    def _idle(self, seconds):
        """
        Instructs the run() method to sleep for "seconds" seconds.
        """
        Utils.is_type(seconds, int)
        self.__idle = int(seconds)

    def _done(self):
        """
        Instructs the run() method to exit thread.
        """
        self.__done = True

    def _initialize(self):
        """
        Overridable method that the run() method executes before entering the
        work loop.
        """
        pass

    def _finalize(self):
        """
        Overridable method that the run() method executes after exiting the
        work loop.
        """
        pass

    def run(self, args={}):
        """
        The run() method that is used as thread. Contains the logic to run the
        task and listen to signals. This method should not be overriden. It
        also catches all uncaught exceptions and logs them as CRITICAL with
        traceback. It is recommended to not handle unexpected exceptions, but
        lets the task report them in a standardized manner.
        """
        Utils.is_type(args, dict)
        self.__args = args

        try:
            self.m.begin()
            self._initialize()

            while not (self.__sig.halt() or self.__done):
                clock = self.m.time()
                self.m.heartbeat(clock)
                if self.__sig.is_paused():
                    self.m.state(Task.STATE_PAUSED)
                    sleep_time = self.__sig.pause()
                    self.m.sleep(sleep_time)
                elif self.__idle > 0:
                    self.m.state(Task.STATE_IDLE)
                    self.__idle -= 1
                    time.sleep(1)
                    self.m.idle(1)
                else:
                    self.m.state(Task.STATE_RUNNING)
                    self.work()
                    self.m.sequence(self.m.time() - clock)

            self._finalize()
            self.m.end()
            self.m.state(Task.STATE_DONE)
        except Exception as e:
            self.m.end()
            self.m.state(Task.STATE_CRASHED)
            logger.critical(
                Utils.format_error(
                    e,
                    'Task.run(), Unhandled exception: (' + self.__name + ')'
                ),
                exc_info=True
            )
            sys.exit('#'*9 + ' Program crash due to internal error ' + '#'*9)
        logger.info(
            Utils.format_info(
                'Thread has gracefully halted',
                {'thread': self.__name}
            )
        )

    def work(self):
        """
        The Tasks business logic should be implemented in the work() method.
        """
        raise NotImplementedError


class TaskGroup:
    """
    TaskGroup is to be implemented. With TaskGroup you should be able to
    instantiate, monitor and communicate with Tasks in groups.
    """
    STATE_NOT_STARTED = 'not_started'
    STATE_RUNNING = 'running'
    STATE_PAUSED = 'paused'
    STATE_STOPPED = 'stopped'

    def __init__(self, name, ioc):
        Utils.is_type(ioc, Container)
        Utils.is_type(name, str)

        self.__name = name
        self.__tasks = {}

        self.__run = threading.Event()
        self.__halt = threading.Event()

        self._ioc = ioc
        self._sig = Signal(run=self.__run, halt=self.__halt)

    def name(self):
        """
        Returns task name.
        """
        return self.__name

    def start(self):
        logger.info(Utils.format_info(
            'Starting group',
            {'group': self.__name}
        ))
        self.__run.set()
        self.__halt.clear()

        if not self.__tasks:
            tl = self.task_list()
            for tn in tl:
                task = tl[tn]()
                Utils.is_type(task, Task)
                if task.name() in self.__tasks:
                    raise Utils.format_exception(
                        RuntimeError,
                        self.__class__.__name__,
                        'Task already exists',
                        {'name': task.name()}
                    )
                else:
                    logger.info(Utils.format_info(
                        'Starting thread',
                        {'thread': task.name()}
                    ))
                    thread = threading.Thread(
                        target=task.run,
                        name=task.name()
                    )
                    thread.start()
                    self.__tasks[task.name()] = {
                        'task': task,
                        'thread': thread
                    }

    def suspend(self):
        """
        Pauses the threads by setting the "run" signal to False.
        """
        logger.info(Utils.format_info(
            'Suspending group',
            {'group': self.__name}
        ))
        self.__run.clear()

    def resume(self):
        """
        Resumes the paused threads by setting the "run" signal to True.
        """
        logger.info(Utils.format_info(
            'Resuming group',
            {'group': self.__name}
        ))
        self.__run.set()

    def stop(self):
        """
        Halts all the threads by setting the run signal to False. Then cleans
        up all the threads.
        """
        logger.info(Utils.format_info('Halting group', {'group': self.__name}))
        self.__halt.set()
        self.__run.set()

    def reset(self):
        """@todo"""
        self.__run.set()
        self.__halt.clear()
        self.__tasks = {}

    def monitor(self):
        """
        monitor returns the running status of the Task's threads.
        """
        # Reimplement with using data from Signal class
        status = {}

        # 0. Daemon
        # 1. Alive
        # 2. State
        # 3. Sequence
        # 4. Uptime
        # 5. Idle
        # 6. Sleep
        # 7. Heartbeat
        for t in list(self.__tasks.keys()):
            status[t] = [
                self.__tasks[t]['thread'].isDaemon(),
                self.__tasks[t]['thread'].isAlive()
            ] + self.__tasks[t]['task'].m.performance()

        return status

    def task_list(self):
        """
        Returns a list with the Task class types that this specific TaskGroup
        implementation controls.

        Example:

        def task_list(self):
            return [
            (MyTask1, ['Database', 'Logger', 'ServiceX']),
            (MyTask2, ['Database', 'Logger', 'ServiceX']),
            (MyTask3, ['Database', 'Logger', 'ServiceX'])
            ]
        """
        raise NotImplementedError


class TaskManager(Service):
    """@todo"""
    KILL_RANGE = 10

    def __init__(self, name, groups, runlevels, ioc):
        Utils.is_type(groups, list)
        Utils.is_type(runlevels, list)
        Utils.is_type(ioc, Container)
        Service.__init__(self, name)

        self.__classes = []
        self.__groups = {}
        self.__runlevels = runlevels
        self.__level = 0
        self.__ioc = ioc

        for pkg in groups:
            self.__classes.append(Utils.imp_pkg(pkg))

    def initialize(self, klass):
        Utils.is_class(klass, TaskGroup)
        if klass.NAME not in self.__groups:
            group = klass(klass.NAME, self.__ioc)
            group.start()
            self.__groups[group.name()] = group

    def finalize(self, klass):
        Utils.is_type(klass, TaskGroup)
        if klass.NAME in self.__groups:
            group = self.__groups[klass.NAME]
            group.stop()
            self.__groups.pop(klass.NAME, None)

    def level(self):
        return self.__level

    def level_exec(self, level):
        """
        runlevel synchronizes the running TaskGroups with the expected groups
        to run. Simply stops and removes groups that shouldn't run and starts
        and add groups that are expected.
        """
        Utils.is_type(level, int)

        if not level < len(self.__runlevels):
            raise Utils.format_exception(
                ValueError,
                self.__class__.__name__,
                'Invalid runlevel',
                {'level': level}
            )

        logger.info(Utils.format_info(
            'Executing runlevel', {'runlevel': level}
        ))
        self.__level = level

        # Find all classes at runlevel
        classes = {}
        for i in self.__runlevels[level]:
            klass = self.__classes[i]
            classes[klass.NAME] = klass

        # Finalize TaskGroups that are not among classes
        for group in list(self.__groups.keys()):
            if group not in classes:
                self.finalize(self.__groups[group])

        # Initialze TaskGroups that are not among groups
        for klass_name in classes:
            if klass_name not in self.__groups:
                self.initialize(classes[klass_name])

    def group(self, name):
        """
        Returns an instance of a TaskGroup for handling.
        Name        The name of the TaskGroup
        """
        Utils.is_type(name, str)
        if name not in self.__groups:
            raise Utils.format_exception(
                ValueError,
                self.__class__.__name__,
                'TaskGroup not existent'
            )

        return self.__groups[name]

    def groups(self):
        """@todo"""
        return list(self.__groups.keys())

    def stop(self):
        """
        Halts all the threads by setting the run signal to False. Then cleans
        up all the threads.
        """
        logger.info(Utils.format_info('Halting all threads'))
        for name in self.__groups:
            self.__groups[name].stop()

        for i in range(TaskManager.KILL_RANGE):
            if threading.active_count() > 1:
                time.sleep(1)
            else:
                logger.info(Utils.format_info('All threads halted'))
                return True
        logger.error(Utils.format_info('Couldn\'t halt all threads'))
        return False

    @staticmethod
    def factory(**kwargs):
        Utils.is_type(kwargs, dict)
        Utils.is_type(kwargs['name'], str)
        Utils.is_type(kwargs['ioc'], Container)
        Utils.is_type(kwargs['params'], dict)

        return TaskManager(
            kwargs['name'],
            kwargs['params']['groups'],
            kwargs['params']['runlevels'],
            kwargs['ioc']
        )
