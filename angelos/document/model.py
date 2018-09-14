import uuid
import types
import datetime
import yaml


class BaseDocument:
    id = None
    type = ''
    created = None
    expires = None

    def __init__(self, data={}):
        self.__readonly = False
        for k in data.items():
            self.__dict__[k] = data[k]

        if not self.id:
            self.id = uuid.uuid4().urn[9:]

        if not self.created:
            self.created = str(datetime.date.today())

        if not self.expires:
            self.expires = str(datetime.date.today() +
                               datetime.timedelta(13*365/12))

        if bool(self.signature):
            self.__readonly = True

    def is_ro(self):
        return self.__readonly

    def make_ro(self):
        self.__readonly = True

    def _all(self):
        all = {}
        for key in dir(self):
            attr = getattr(self, key)
            if not key.startswith('_') and not isinstance(
                    attr, (types.FunctionType, types.MethodType)):
                if key in self.__dict__.keys():
                    all[key] = self.__dict__[key]
                else:
                    all[key] = None
        return all

    def validate(self):
        pass

    def yaml(self):
        return yaml.dump(self._all(),
                         default_flow_style=False,
                         width=80,
                         indent=True,
                         explicit_start=True,
                         explicit_end=True)


class BaseDocumentMixin:
    @staticmethod
    def properties():
        return {}
