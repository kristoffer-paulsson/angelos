import importlib
import threading
import types
from peewee import SqliteDatabase, Database as PWDatabase
from .ioc import Service
from .utils import Utils

"""
The db.py module containes application wrappers and helper classes to work with
databases within the application such as the Database wrapper class and the
DatabaseManager class.
"""


class Database:
    """
    A Database wrapper for Database and ORM connection for peewee.
    """
    def __init__(self, db):
        # peewee.SqliteDatabase,
        # peewee.MySQLDatabase,
        # peewee.PostgresqlDatabase)
        Utils.is_type(db, PWDatabase)
        self.__db = db
        self.__lock = threading.Lock()

    def get(self):
        return self.__db

    def lock(self):
        self.__lock.acquire()

    def unlock(self):
        self.__lock.release()


class DatabaseManager(Service):
    """
    Databasemanager service for the Application
    """
    NAME = 'DatabaseManager'

    def __init__(self, config={}):
        Utils.is_type(config, types.DictType)

        Service.__init__(self, self.NAME, config)
        self.__instances = {}

    def __instantiate(self, name):
        Utils.is_type(name, types.StringType)
        if name not in self.__instances:
            c = self._config()
            cc = c[name]
            if 'type' not in cc:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Database connection must configure "type".',
                    {'name': name}
                )

            if 'class' not in cc:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Database connection must configure "class".',
                    {'name': name}
                )

            try:
                pkg = cc['class'].rsplit('.', 1)
                klass = getattr(importlib.import_module(pkg[0]), pkg[1])
            except ImportError:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Database class not found.',
                    {'class': str(cc['class'])}
                )

            if cc['type'] == 'sqlite':
                conn = SqliteDatabase(Utils.app_dir() + cc['path'])
                db = klass(conn)
                if not isinstance(db, Database):
                    raise Utils.format_exception(
                        TypeError,
                        self.__class__.__name__,
                        'Database connection "package" not of type Database.',
                        {'name': str(name)}
                    )
                    raise TypeError(
                        'Database connection "' + str(name) +
                        '" "package" not of type Database.')
            else:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Database connection "type" value is invalid.',
                    {'name': str(name)}
                )

            self.__instances[name] = db

        return self.__instances[name]

    def get(self, name):
        Utils.is_type(name, types.StringType)
        if name not in self._config():
            raise Utils.format_exception(
                RuntimeError,
                self.__class__.__name__,
                'Database connection not configured.',
                {'name': str(name)}
            )
        else:
            return self.__instantiate(name)