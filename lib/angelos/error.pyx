# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
from enum import IntEnum


class AngelosException(Exception): pass  # noqa E701
class ContainerServiceNotConfigured(AngelosException): pass  # noqa E302
class ContainerLambdaExpected(AngelosException): pass  # noqa E302
class WorkerAlreadyRegistered(AngelosException): pass  # noqa E302
class WorkerNotRegistered(AngelosException): pass  # noqa E302

class CmdShellException(AngelosException): pass  # noqa E302
class CmdShellDuplicate(CmdShellException): pass  # noqa E302
class CmdOptionIllegalValue(CmdShellException): pass  # noqa E302
class CmdOptionIllegalChoice(CmdShellException): pass  # noqa E302
class CmdOptionChoiceOmitted(CmdShellException): pass  # noqa E302
class CmdOptionValueOmitted(CmdShellException): pass  # noqa E302
class CmdOptionMultipleValues(CmdShellException): pass  # noqa E302
class CmdOptionUnkown(CmdShellException): pass  # noqa E302
class CmdOptionTypeInvalid(CmdShellException): pass  # noqa E302
class CmdShellConfused(CmdShellException): pass  # noqa E302
class CmdUnknownError(CmdShellException): pass  # noqa E302
class CmdShellInvalidCommand(CmdShellException): pass  # noqa E302
class CmdShellEmpty(CmdShellException): pass  # noqa E302
class CmdShellExit(CmdShellException): pass  # noqa E302
class CmdOptionMutuallyExclusive(CmdShellException): pass  # noqa E302
class CmdOptionDemandAny(CmdShellException): pass  # noqa E302
class CmdOptionDemandAll(CmdShellException): pass  # noqa E302
class CmdOptionCombine(CmdShellException): pass  # noqa E302

class EventsAddressTaken(AngelosException): pass  # noqa E302
class EventsAddressRemoved(AngelosException): pass  # noqa E302
class EventsAddressMissing(AngelosException): pass  # noqa E302
class IssuanceInvalid(AngelosException): pass  # noqa E302

class ModelException(AngelosException): pass  # noqa E302
class FieldRequiredNotSet(ModelException): pass  # noqa E302
class FieldNotMultiple(ModelException): pass  # noqa E302
class FieldInvalidType(ModelException): pass  # noqa E302
class FieldInvalidChoice(ModelException): pass  # noqa E302
class DocumentShortExpiery(ModelException): pass  # noqa E302
class DocumentInvalidType(ModelException): pass  # noqa E302
class DocumentPersonNotInNames(ModelException): pass  # noqa E302
class FieldInvalidEmail(ModelException): pass  # noqa E302
class FieldBeyondLimit(ModelException): pass  # noqa E302
class FieldIsMultiple(ModelException): pass  # noqa E302

class ConcealException(AngelosException): pass  # noqa E302
class ConcealUnkownMode(ConcealException): pass  # noqa E302
class ConcealPositionError(ConcealException): pass  # noqa E302
class ConcealInvalidSeek(ConcealException): pass  # noqa E302

class Archive7Exception(AngelosException): pass  # noqa E302
class ArchiveInvalidFormat(Archive7Exception): pass  # noqa E302
class ArchiveInvalidCompression(Archive7Exception): pass  # noqa E302
class ArchiveNotFound(Archive7Exception): pass  # noqa E302
class ArchiveWrongEntry(Archive7Exception): pass  # noqa E302
class ArchiveInvalidDelMode(Archive7Exception): pass  # noqa E302
class ArchivePathInvalid(Archive7Exception): pass  # noqa E302
class ArchiveLink2Link(Archive7Exception): pass  # noqa E302
class ArchiveDigestInvalid(Archive7Exception): pass  # noqa E302
class ArchiveBlankFailure(Archive7Exception): pass  # noqa E302
class ArchiveDataMissing(Archive7Exception): pass  # noqa E302
class ArchiveInvalidDir(Archive7Exception): pass  # noqa E302
class ArchivePathBroken(Archive7Exception): pass  # noqa E302
class ArchiveLinkBroken(Archive7Exception): pass  # noqa E302
class ArchiveInvalidFile(Archive7Exception): pass  # noqa E302
class ArchiveInvalidSeek(Archive7Exception): pass  # noqa E302
class ArchiveOperandInvalid(Archive7Exception): pass  # noqa E302
class ArchiveNameTaken(Archive7Exception): pass  # noqa E302
class ArchiveNotEmpty(Archive7Exception): pass  # noqa E302


class LogoException(Exception):
    pass


ERROR_INFO = {
    500: (ContainerServiceNotConfigured, 'The accessed service is not configured in the IoC container'),  # noqa E501
    501: (ContainerLambdaExpected, 'The service is not configured with lambda function in the IoC container'),  # noqa E501
    510: (WorkerAlreadyRegistered, 'The worker name is already occupied'),  # noqa E501
    511: (WorkerNotRegistered, 'The worker could not be found'),  # noqa E501

    521: (CmdShellDuplicate, 'The command is already loaded'),  # noqa E501
    522: (CmdOptionIllegalValue, 'Command option value should be omitted'),  # noqa E501
    523: (CmdOptionIllegalChoice, 'Invalid choice for command option'),  # noqa E501
    524: (CmdOptionChoiceOmitted, 'Omitted choice for command option'),  # noqa E501
    525: (CmdOptionValueOmitted, 'Omitted value for command option'),  # noqa E501
    526: (CmdOptionMultipleValues, 'More than one value for command option'),  # noqa E501
    527: (CmdOptionUnkown, 'Unkown option found'),  # noqa E501
    528: (CmdOptionTypeInvalid, 'Command option type is not set or invalid'),  # noqa E501
    529: (CmdShellConfused, 'Shell failed to interpret command'),  # noqa E501
    530: (CmdUnknownError, 'Simply an unknown error'),  # noqa E501
    531: (CmdShellInvalidCommand, 'Command is unknown or invalid'),  # noqa E501
    532: (CmdShellEmpty, 'Command line is empty'),  # noqa E501
    533: (CmdShellExit, 'Exits terminal session'),  # noqa E501
    534: (CmdOptionMutuallyExclusive, 'Command option is mutually exclusice'),  # noqa E501
    535: (CmdOptionDemandAny, 'Command option demand one other option present'),  # noqa E501
    536: (CmdOptionDemandAll, 'Command option demand several other options present'),  # noqa E501
    537: (CmdOptionCombine, 'Command option must be combined with another option'),  # noqa E501

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
    608: (FieldBeyondLimit, 'Given data to large'),  # noqa E501
    609: (FieldIsMultiple, 'Value is not list, but set to multiple'),  # noqa E501

    700: (ConcealUnkownMode, 'Conceal doesn\'t support unkown format'),  # noqa E501
    701: (ConcealPositionError, 'Error when seeking in underlying file object'),  # noqa E501
    702: (ConcealInvalidSeek, 'The given seek method is invalid'),  # noqa E501

    720: (ArchiveInvalidFormat, 'Invalid identifier, not an Archive7 file'),
    721: (ArchiveInvalidCompression, 'Invalid or unknown compression type'),
    722: (ArchiveNotFound, 'Archive file not found'),
    723: (ArchiveWrongEntry, 'Wrong entry type, another type expected'),
    724: (ArchiveInvalidDelMode, 'Invalid or unknown delete mode'),
    725: (ArchivePathInvalid, 'No such path in archive'),
    726: (ArchiveLink2Link, 'Invalid link to another link entry'),
    727: (ArchiveDigestInvalid, 'Checksum is invalid for file entry'),
    728: (ArchiveBlankFailure, 'Failed making new blank entries'),
    729: (ArchiveDataMissing, 'No file data to save'),
    730: (ArchiveInvalidDir, 'Invalid directory'),
    731: (ArchivePathBroken, 'Existing path of outside hierarchy'),
    732: (ArchiveLinkBroken, 'Link is broken'),
    733: (ArchiveInvalidFile, 'File not in directory'),
    734: (ArchiveInvalidSeek, 'Failed to seek to position in file'),
    735: (ArchiveOperandInvalid, 'Invalid or unsupported operand'),
    736: (ArchiveNameTaken, 'Name is taken in directory'),
    737: (ArchiveNotEmpty, 'Directory is not empty.'),
}


class Error(IntEnum):

    IOC_NOT_CONFIGURED = 500  # 10 Error codes reserved for ioc
    IOC_LAMBDA_EXPECTED = 501
    WORKER_ALREADY_REGISTERED = 510  # 20 Error codes reserved for workers
    WORKER_NOT_REGISTERED = 511

    CMD_SHELL_DUPLICATE = 521  # 1 Error code for commands
    CMD_OPT_ILLEGAL_VALUE = 522
    CMD_OPT_ILLEGAL_CHOICE = 523
    CMD_OPT_CHOICE_OMITTED = 524
    CMD_OPT_VALUE_OMITTED = 525
    CMD_OPT_MULTIPLE_VALUES = 526
    CMD_OPT_UNKNOWN = 527
    CMD_OPT_TYPE_INVALID = 528
    CMD_SHELL_CONFUSED = 529
    CMD_UNKOWN_ERROR = 530
    CMD_SHELL_INVALID_COMMAND = 531
    CMD_SHELL_EMPTY = 532
    CMD_SHELL_EXIT = 533
    CMD_OPT_MUT_EXCL = 534
    CMD_OPT_DEM_ANY = 535
    CMD_OPT_DEM_ALL = 536
    CMD_OPT_COMBINE = 537

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
    FIELD_BEYOND_LIMIT = 608
    FIELD_IS_MULTIPLE = 609

    # 20 error codes for Conceal
    CONCEAL_UNKOWN_MODE = 700
    CONCEAL_POSITION_ERROR = 701
    CONCEAL_INVALID_SEEK = 702

    # 20 error codes for Archive7
    AR7_INVALID_FORMAT = 720
    AR7_INVALID_COMPRESSION = 721
    AR7_NOT_FOUND = 722
    AR7_WRONG_ENTRY = 723
    AR7_INVALID_DELMODE = 724
    AR7_PATH_INVALID = 725
    AR7_LINK_2_LINK = 726
    AR7_DIGEST_INVALID = 727
    AR7_BLANK_FAILURE = 728
    AR7_DATA_MISSING = 729
    AR7_INVALID_DIR = 730
    AR7_PATH_BROKEN = 731
    AR7_LINK_BROKEN = 732
    AR7_INVALID_FILE = 733
    AR7_INVALID_SEEK = 734
    AR7_OPERAND_INVALID = 735
    AR7_NAME_TAKEN = 736
    AR7_NOT_EMPTY = 737
