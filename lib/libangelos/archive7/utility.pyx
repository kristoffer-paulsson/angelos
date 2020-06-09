# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Archive utility."""
import asyncio
import binascii
import getpass
import hashlib
import logging
import math
import re
import sys

from libangelos.library.nacl import SecretBox

BYTES_SUF = ("B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB")
ENDING_SUF = (".ar7", ".log.ar7", ".tar.ar7")
REGEX_KEY = r"^[0-9a-fA-F]{64}$"

def out(*args):
    """Stream wrapper for sys.stdout."""
    sys.stdout.write(" ".join([str(s) for s in args]) + "\n")

def err(*args):
    """Stream wrapper for sys.stderr."""
    sys.stderr.write(" ".join([str(s) for s in args]) + "\n")

def get_key(args, generate=False):
    """Receive encryption key if --key argument not set."""
    msg = (
        "\nArchives are encrypted, a key is "
        "necessary in order to work with them."
    )
    if args.key:
        if re.match(REGEX_KEY, args.key):
            return binascii.unhexlify(args.key)
        else:
            return binascii.unhexlify(
                hashlib.sha512(args.key.encode()).hexdigest()[64:]
            )

    else:
        out(msg)
        key = getpass.getpass(
            "Encryption key or password%s: "
            % (" (leave blank for autogen)" if generate else "")
        ).encode("utf-8")

    if re.match(REGEX_KEY, key.decode()):
        return binascii.unhexlify(key)
    elif len(key) == 0 and generate:
        out("\nGenerate encryption key!\n")
        key = SecretBox().sk
        out(
            "The new encryption key is:\n"
            + "\033[32m%s\033[0m\n(\033[36;5mMake a backup!\033[0m)\n"
            % (binascii.hexlify(key).decode())
        )
        return key
    else:
        out(
            "\nAssume it's a password. "
            + "(\033[33;5mWeak cryptography!!!\033[0m)\n"
        )
        return binascii.unhexlify(hashlib.sha512(key).hexdigest()[64:])

def file_size(size):
    """Human readable filesize."""
    order = int(math.log2(size) / 10) if size else 0
    return "{:<5.4g} {:}".format(size / (1 << (order * 10)), BYTES_SUF[order])

def main():
    """Ar7 utility main method."""
    import argparse

    description = (
        "Archive7/ConcealIO encrypted and "
        "compressed archive commandline utility."
    )

    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "-k", "--key", metavar="<key>", default=False, help="Encryption key"
    )
    parser.add_argument(
        "-z",
        "--zip",
        action="store_true",
        default=False,
        help="Use compression",
    )
    parser.add_argument(
        "-u",
        "--unix",
        action="store_true",
        default=False,
        help="Regard Unix ownership and permissions",
    )
    parser.add_argument(
        "-q",
        "--quite",
        action="store_true",
        default=False,
        help="Silence all output",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        default=False,
        help="Force extraction if file exists",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        help="Verbose output",
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "-l", "--list", metavar="<archive>", help="Show listing of an archive"
    )
    group.add_argument(
        "-e",
        "--extract",
        nargs="+",
        metavar=("<archive>", "<output_dir>"),
        help="Extract archive into target dir",
    )
    group.add_argument(
        "-c",
        "--create",
        nargs="+",
        metavar=("<name>", "<file>"),
        help="Create archive from sources",
    )
    group.add_argument(
        "-t", "--test", metavar="<archive>", help="Test if a archive is valid"
    )

    args = parser.parse_args()

    if args.zip and not args.create:
        parser.error("-z/--zip can only be used with -c/--create.")
    if args.unix and not (args.create or args.extract):
        parser.error(
            "-u/--unix can only be used " + "with -c/--create or -e/--extract."
        )
    if args.quite and not args.key:
        parser.error("-f/--force can only be used with -e/--extract.")
    if args.verbose and args.quite:
        parser.error("-v/--verbose can not be used with -q/--quite.")
    if args.quite and not args.key:
        parser.error("-k/--key MUST be used with -q/--quite.")

    try:
        if args.test is not None:
            # run_test(args, parser)
            pass
        elif args.list is not None:
            # asyncio.run(run_list(args, parser))
            pass
        elif args.extract is not None:
            # run_extract(args, parser)
            pass
        elif args.create is not None:
            # run_create(args, parser)
            pass

    except (binascii.Error, ValueError) as e:
        if args.verbose:
            err("-" * 20, "Verbose info start", "-" * 20)
            logging.exception(e)
            err("-" * 21, "Verbose info end", "-" * 21)
        if not args.quite:
            parser.exit(1, "Program exited because of: %s.\n\n" % e)
        else:
            parser.exit(1)

    except Exception as e:
        if not args.quite:
            err("-" * 20, "\033[33mCrash report start\033[0m", "-" * 20)
            logging.exception(e)
            err("-" * 21, "\033[33mCrash report end\033[0m", "-" * 21)
            parser.exit(2)

    parser.exit(0)
