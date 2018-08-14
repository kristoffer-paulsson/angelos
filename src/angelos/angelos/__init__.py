import sys
from angelos.server import Server
from app import Daemonizer

'''
angelos: Main module

Copyright 2018, Kristoffer Paulsson
Licensed under MIT.
'''
CONFIG = {
    'tasks': {
        'class': 'app.task.TaskManager',
        'params': {
            'groups': [
                'app.core.Core',
                'app.tasks.dummy.Dummies',
                'angelos.connect.Connect'
            ],
            'runlevels': [
                [],
                [0],
                [0, 1, 2]
            ]
        }
    },
    'cmd': {
        'class': 'app.cmd.CMD',
        'params': {
            'commands': [
                'app.core.commands.QuitCommand',
                'app.core.commands.TaskCommand',
                'app.core.commands.RunLevelCommand',
                'app.core.settings.EnvCommand'
            ]
        }
    },
    'environment': {
        'class': 'app.core.settings.Settings',
        'params': {
            'agent': 'angelos',
            'version': '1.0dX',
            'runlevel': 2
        }
    }
}


def main():
    """@todo"""
    server = Daemonizer(Server(CONFIG), '/tmp/angelos_server.pid')
    if len(sys.argv) == 2:
        if sys.argv[1] == 'start':
            server.start()
        elif sys.argv[1] == 'stop':
            server.stop()
            print('Daemon stopped')
        elif sys.argv[1] == 'restart':
            server.restart()
        else:
            print('Unknown command')
            sys.exit(2)
        sys.exit(0)
    else:
        print(('To daemonize: %s start|stop|restart' % sys.argv[0]))
        print('Type Ctrl^C to stop execution...')
        server.start(False)
        sys.exit(0)
