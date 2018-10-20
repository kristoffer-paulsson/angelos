from enum import IntEnum


class AngelosException(Exception): pass  # noqa E701
class ContainerServiceNotConfigured(AngelosException): pass  # noqa E302
class ContainerLambdaExpected(AngelosException): pass  # noqa E302
class WorkerAlreadyRegistered(AngelosException): pass  # noqa E302
class WorkerNotRegistered(AngelosException): pass  # noqa E302

class CmdShellException(AngelosException): pass  # noqa E302
class CmdShellDuplicate(CmdShellException): pass  # noqa E302
class CmdOptionIllegalValue(CmdShellException): pass  # noqa E302
class CmdOptionIllegalChoise(CmdShellException): pass  # noqa E302
class CmdOptionChoiseOmitted(CmdShellException): pass  # noqa E302
class CmdOptionValueOmitted(CmdShellException): pass  # noqa E302
class CmdOptionMultipleValues(CmdShellException): pass  # noqa E302
class CmdOptionMandatoryOmitted(CmdShellException): pass  # noqa E302
class CmdOptionTypeInvalid(CmdShellException): pass  # noqa E302
class CmdShellConfused(CmdShellException): pass  # noqa E302
class CmdUnknownError(CmdShellException): pass  # noqa E302
class CmdShellInvalidCommand(CmdShellException): pass  # noqa E302
class CmdShellEmpty(CmdShellException): pass  # noqa E302
class CmdShellExit(CmdShellException): pass  # noqa E302

class EventsAddressTaken(AngelosException): pass  # noqa E302
class EventsAddressRemoved(AngelosException): pass  # noqa E302
class EventsAddressMissing(AngelosException): pass  # noqa E302
class IssuanceInvalid(AngelosException): pass  # noqa E302

class FieldRequiredNotSet(AngelosException): pass  # noqa E302
class FieldNotMultiple(AngelosException): pass  # noqa E302
class FieldInvalidType(AngelosException): pass  # noqa E302
class FieldInvalidChoice(AngelosException): pass  # noqa E302
class DocumentShortExpiery(AngelosException): pass  # noqa E302
class DocumentInvalidType(AngelosException): pass  # noqa E302
class DocumentPersonNotInNames(AngelosException): pass  # noqa E302
class FieldInvalidEmail(AngelosException): pass  # noqa E302


class LogoException(Exception):
    pass


ERROR_INFO = {
    500: (ContainerServiceNotConfigured, 'The accessed service is not configured in the IoC container'),  # noqa E501
    501: (ContainerLambdaExpected, 'The service is not configured with lambda function in the IoC container'),  # noqa E501
    510: (WorkerAlreadyRegistered, 'The worker name is already occupied'),  # noqa E501
    511: (WorkerNotRegistered, 'The worker could not be found'),  # noqa E501

    521: (CmdShellDuplicate, 'The command is already loaded'),  # noqa E501
    522: (CmdOptionIllegalValue, 'Command option value should be omitted'),  # noqa E501
    523: (CmdOptionIllegalChoise, 'Invalid choise for command option'),  # noqa E501
    524: (CmdOptionChoiseOmitted, 'Omitted choise for command option'),  # noqa E501
    525: (CmdOptionValueOmitted, 'Omitted value for command option'),  # noqa E501
    526: (CmdOptionMultipleValues, 'More than one value for command option'),  # noqa E501
    527: (CmdOptionMandatoryOmitted, 'Mandatory command option omitted'),  # noqa E501
    528: (CmdOptionTypeInvalid, 'Command option type is not set or invalid'),  # noqa E501
    529: (CmdShellConfused, 'Shell failed to interpret command'),  # noqa E501
    530: (CmdUnknownError, 'Simply an unknown error'),  # noqa E501
    531: (CmdShellInvalidCommand, 'Command is unknown or invalid'),  # noqa E501
    532: (CmdShellEmpty, 'Command line is empty'),  # noqa E501
    533: (CmdShellExit, 'Exits terminal session'),  # noqa E501

    540: (EventsAddressTaken, 'The sender address is already taken'),  # noqa E501
    541: (EventsAddressRemoved, 'The sender address is already removed'),  # noqa E501
    542: (EventsAddressMissing, 'The sender/recepient address doesn\'t exist'),  # noqa E501
    550: (IssuanceInvalid, 'The signature for the issue is invalid'),  # noqa E501

    600: (FieldRequiredNotSet, 'Required value is not set'),  # noqa E501
    601: (FieldNotMultiple, 'Value is list, but not set to multiple'),  # noqa E501
    602: (FieldInvalidType, 'Value type is invalid'),  # noqa E501
    603: (FieldInvalidChoice, 'Value not among acceptable choices'),  # noqa E501
    604: (DocumentShortExpiery, 'Expiery date to short'),  # noqa E501
    605: (DocumentInvalidType, 'Invalid type set'),  # noqa E501
    606: (DocumentPersonNotInNames, 'Given name not in names'),  # noqa E501
    607: (FieldInvalidEmail, 'Given email not a regular email address'),  # noqa E501

}


class Error(IntEnum):

    IOC_NOT_CONFIGURED = 500  # 10 Error codes reserved for ioc
    IOC_LAMBDA_EXPECTED = 501
    WORKER_ALREADY_REGISTERED = 510  # 20 Error codes reserved for workers
    WORKER_NOT_REGISTERED = 511

    CMD_SHELL_DUPLICATE = 521  # 1 Error code for commands
    CMD_OPT_ILLEGAL_VALUE = 522
    CMD_OPT_ILLEGAL_CHOISE = 523
    CMD_OPT_CHOISE_OMITTED = 524
    CMD_OPT_VALUE_OMITTED = 525
    CMD_OPT_MULTIPLE_VALUES = 526
    CMD_OPT_MANDATORY_OMITTED = 527
    CMD_OPT_TYPE_INVALID = 528
    CMD_SHELL_CONFUSED = 529
    CMD_UNKOWN_ERROR = 530
    CMD_SHELL_INVALID_COMMAND = 531
    CMD_SHELL_EMPTY = 532
    CMD_SHELL_EXIT = 533

    EVENT_ADDRESS_TAKEN = 540  # 10 error codes for events
    EVENT_ADDRESS_REMOVED = 541
    EVENT_ADDRESS_MISSING = 542

    ISSUANCE_INVALID_ISSUE = 550

    FIELD_NOT_SET = 600  # 100 error codes for models and facade
    FIELD_NOT_MULTIPLE = 601
    FIELD_INVALID_TYPE = 602
    FIELD_INVALID_CHOICE = 603
    DOCUMENT_SHORT_EXPIREY = 604
    DOCUMENT_INVALID_TYPE = 605
    DOCUMENT_PERSON_NAMES = 606
    FIELD_INVALID_EMAIL = 607
