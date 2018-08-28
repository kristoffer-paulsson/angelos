import time
# from .common import quit, logger
from ..ioc import Container
from .cmd import Command, ConsoleAdapter
from ..utils import Util


class DummyCommand(Command):
    cmd = 'dummy'
    short = 'Dummy test command'

    def __init__(self, adapter):
        Command.__init__(self, adapter)

    def _arguments(self, parser):
        parser.add_argument('-y', '--yes', action='store_true',
                            help='Confirms that you said yes')

    def _execute(self, args):
        adapter = self._adapter()
        if not args.yes:
            adapter.write('You did confirm by saying yes')
            return
        adapter.write('Dummy command executed')
        return True

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['adapter'], ConsoleAdapter)
        return DummyCommand(adapter=kwargs['adapter'])


class QuitCommand(Command):
    cmd = 'quit'
    short = 'Stops execution and shuts down program'

    def __init__(self, adapter):
        Command.__init__(self, adapter)

    def _arguments(self, parser):
        parser.add_argument('-y', '--yes', action='store_true',
                            help='Confirms that you want to stop execution')

    def _execute(self, args):
        if not args.yes:
            print('Shut down not confirmed')
            return
        print('Shutting down server')
        # logger.info(Util.format_info(
        #    '"Quit" user command. Shutting down program')
        # )
        quit.set()
        return True

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['adapter'], ConsoleAdapter)
        return QuitCommand(adapter=kwargs['adapter'])


class WorkerCommand(Command):
    cmd = 'task'
    short = 'Carry out operation relating to task management'

    def __init__(self, adapter, task_manager):
        Command.__init__(self, adapter)
        # Util.is_type(task_manager, TaskManager)
        self.__task_manager = task_manager

    def _arguments(self, parser):
        parser.add_argument('-y', '--yes', action='store_true',
                            help='confirms that the user is sure.')
        g = parser.add_mutually_exclusive_group()
        g.add_argument('-s', '--status', action='store_true',
                       help='shows the current status of ongoing tasks')
        g.add_argument('-k', '--kill', nargs=1, type=str,
                       help='halts execution of given task ' +
                       'group, confirmation required')
        g.add_argument('-l', '--launch', nargs=1, type=str,
                       help='launch execution of given task group')
        g.add_argument('-p', '--pause', nargs=1, type=str,
                       help='pauses execution of given task group')
        g.add_argument('-c', '--continue', nargs=1, type=str,
                       help='continue execution of given paused task group')
        g.add_argument('-r', '--reboot', nargs=1, type=str,
                       help='reboot (kill and spawn) given task ' +
                       'group, confirmation required')

    def _execute(self, args):
        if bool(args.status):
            self.__status()
        elif bool(args.kill):
            self.__kill(args.kill[0], args.yes)
        elif bool(args.launch):
            self.__launch(args.launch[0])
        elif bool(args.pause):
            self.__pause(args.pause[0])
        elif bool(args.__dict__['continue']):
            self.__continue(args.__dict__['continue'][0])
        elif bool(args.reboot):
            self.__reboot(args.reboot[0], args.yes)
        else:
            print('Not implemented')

    def __status(self):
        hstr = '{:24} | {:7} | {:5} | {:8} | {:5} | {:8} | {:8} | {:5} | {:5}'
        mstr = '{:24} | {:7} | {:5} | {:>8} | {:5} | {:>8} | {:>8} | {:>5.4} | {:5}' # noqa E501
        groups = self.__task_manager.groups()

        print('\nStatus of tasks:')
        print(hstr.format('Name',   'State', 'Live',
                          'Uptime', 'Beat',  'Idle',
                          'Sleep',  'Seq',   'Dmn'))
        print('-'*99)
        # 0. Daemon
        # 1. Alive
        # 2. State
        # 3. Sequence
        # 4. Uptime
        # 5. Idle
        # 6. Sleep
        # 7. Heartbeat

        for group_name in groups:
            info = self.__task_manager.group(group_name).monitor()
            for t in info:
                print(mstr.format(
                    group_name + '.' + t,
                    str(info[t][2]).upper(),
                    str(bool(info[t][1])),
                    Util.hours(info[t][4]),
                    str(bool(info[t][7] - time.time() < 10)),
                    Util.hours(info[t][5]),
                    Util.hours(info[t][6]),
                    info[t][3],
                    str(bool(info[t][0]))
                ))
        print('\n')

    def __kill(self, group_name, confirmed):
        if not confirmed:
            print('Killing task group "' + group_name + '" is not confirmed')
            return
        try:
            # logger.info(Util.format_info(
            #    '"Task" user command. Killing task group',
            #    {'group_name': group_name}
            # ))
            print('Killing task group')
            self.__task_manager.group(group_name).stop()
        except ValueError:
            print('Group "' + group_name + '" isn\'t loaded')

    def __launch(self, group_name):
        try:
            # logger.info(Util.format_info(
            #    '"Task" user command. Launch task group',
            #    {'group_name': group_name}
            # ))
            print('Starting task group')
            g = self.__task_manager.group(group_name)
            g.reset()
            g.start()
        except ValueError:
            print('Group "' + group_name + '" isn\'t loaded')

    def __pause(self, group_name):
        try:
            # logger.info(Util.format_info(
            #    '"Task" user command. Pause task group',
            #    {'group_name': group_name}
            # ))
            print('Pause task group')
            self.__task_manager.group(group_name).suspend()
        except ValueError:
            print('Group "' + group_name + '" isn\'t loaded')

    def __continue(self, group_name):
        try:
            # logger.info(Util.format_info(
            #    '"Task" user command. Resume task group',
            #    {'group_name': group_name}
            # ))
            print('Resuming task group')
            self.__task_manager.group(group_name).resume()
        except ValueError:
            print('Group "' + group_name + '" isn\'t loaded')

    def __reboot(self, group_name, confirmed):
        if not confirmed:
            print('Rebooting task group "' + group_name + '" is not confirmed')
            return
        try:
            print('Rebooting task group')
            # logger.info(Util.format_info(
            #    '"Task" user command. Rebooting task group',
            #    {'group_name': group_name}
            # ))
            g = self.__task_manager.group(group_name)
            g.stop()
            g.reset()
            g.start()
        except ValueError:
            print('Group "' + group_name + '" isn\'t loaded')

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['adapter'], ConsoleAdapter)
        Util.is_type(kwargs['ioc'], Container)

        return WorkerCommand(kwargs['adapter'], kwargs['ioc'].service('tasks'))


class RunLevelCommand(Command):
    cmd = 'runlevel'
    short = 'Set and operate runlevels'

    def __init__(self, adapter, task_manager):
        Command.__init__(self, adapter)
        # Util.is_type(task_manager, TaskManager)
        self.__task_manager = task_manager

    def _arguments(self, parser):
        parser.add_argument('-l', '--level', type=str,
                            help='specifies the new runlevel')

    def _execute(self, args):
        lvl = self.__task_manager.level()
        if not args.level:
            print(lvl)
        elif int(args.level) >= 0:
            goto = int(args.level)
            # logger.info(Util.format_info(
            #    '"Runlevel" user command. Changing runlevel',
            #    {'level': goto}
            # ))
            try:
                if goto > lvl:
                    while goto is not lvl:
                        lvl += 1
                        self.__task_manager.level_exec(lvl)
                        time.sleep(2)
                elif goto < lvl:
                    while goto is not lvl:
                        lvl -= 1
                        self.__task_manager.level_exec(lvl)
                        time.sleep(2)
            except ValueError:
                print('Requested run level to high')
        else:
            print('Run level must be equal or greater than 0')

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['adapter'], ConsoleAdapter)
        Util.is_type(kwargs['ioc'], Container)

        return WorkerCommand(kwargs['adapter'], kwargs['ioc'].service('tasks'))


class EnvCommand(Command):
    cmd = 'env'
    short = 'Manipulates environment settings'

    def __init__(self, adapter, environment):
        Command.__init__(self, adapter)
        self.__env = environment

    def _arguments(self, parser):
        parser.add_argument('op', nargs=1, choices=['list', 'get', 'set'],
                            help='parameter operations')
        parser.add_argument('key', nargs='?', help='parameter key')
        parser.add_argument('value', nargs='?', help='parameter value')

    def _execute(self, args):
        if 'set' in args.op:
            if not args.key:
                print('You must enter a key')
                return
            if not args.value:
                print('You must enter a value')
                return
            if args.key in self.__env.params():
                self.__env.set(args.key, args.value)
                print('Parameter {:} set to: "{:}"'.format(
                    args.key, args.value
                ))
            else:
                print('Environment setting "' + args.key + '" is invalid')
        elif 'get' in args.op:
            if not args.key:
                print('You must enter a key')
                return
            if args.key in self.__env.params():
                print('{:}'.format(self.__env.get(args.key)))
            else:
                print('Environment setting "' + args.key + '" is invalid')
        elif 'list' in args.op:
            for p in self.__env.params():
                print('{:}={:}'.format(p, self.__env.get(p)))

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['adapter'], ConsoleAdapter)
        Util.is_type(kwargs['ioc'], Container)

        return WorkerCommand(kwargs['adapter'],
                             kwargs['ioc'].service('environment'))
