import socket
import paramiko
import paramiko.ssh_exception.SSHException
from app import Utils, Task, logger


class AdminServer(Task):
    NAME = 'AdminServer'

    def __init__(self, name, sig):
        Task.__init__(self, name, sig)

        self.__socket = None
        self.__server = None

    def _initialize(self):
        try:
            DoGSSAPIKeyExchange = False
            # host_key = paramiko.RSAKey(filename="test_rsa.key")

            self.__socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.__socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.__socket.bind(('', 22))

            print 'Socket bind 2200'

            self.__socket.listen(100)
            client, addr = self.__socket.accept()

            print 'Socket accept'

            t = paramiko.Transport(client, gss_kex=DoGSSAPIKeyExchange)
            t.set_gss_host(socket.getfqdn(''))

            print 'Transport received'

            t.load_server_moduli()

            print 'Load server moduli'
            # t.add_server_key(host_key)
            self.__server = self.Server()

            print 'Server loaded'

            t.start_server(server=self.__server)

            print 'Server started'

            chan = t.accept(20)

            print 'Channel accepted'

            self.__server.event.wait(10)

            print 'Waited for server event'

            chan.send('\r\n\r\nWelcome to my dorky little BBS!\r\n\r\n')
            chan.send('We are on fire all the time!  '
                      'Hooray!  Candy corn for everyone!\r\n')
            chan.send('Happy birthday to Robot Dave!\r\n\r\n')
            chan.send('Username: ')
            f = chan.makefile('rU')
            username = f.readline().strip('\r\n')
            chan.send('\r\nI don\'t like you, ' + username + '.\r\n')
            chan.close()

            self.__socket.close()
        except SSHException as e:
            logger.error(Utils.format_error(
                e,
                'Admin SSH error'
            ))

    def _finilize(self):
        pass

    def work(self):
        pass

    class Server(paramiko.ServerInterface):
        pass
