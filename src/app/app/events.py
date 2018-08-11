from .ioc import Service, Initializer


class LogEvent:
    pass


class ExecutionEvent(LogEvent):
    pass


class UserEvent(LogEvent):
    pass


class BusinessEvent(LogEvent):
    pass


class EventLoggerInitializer(Initializer):
    pass


class EventLogger(Service):
    pass
