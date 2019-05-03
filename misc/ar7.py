"""
Module Docstring
"""

__author__ = "Kristoffer Paulsson"
__version__ = "0.1.0"
__license__ = "MIT"


import argparse
import os
import yaml
import libnacl
import libnacl.secret
import plyer
import base64

from angelos.archive.archive7 import Archive, Entry
from angelos.archive.conceal import ConcealIO
from angelos.archive.check import Check

def main(args):
    """ Main entry point of the app """
    path = os.path.realpath(args.file)
    name = os.path.basename(path)
    dirname = os.path.dirname(path)

    if not os.path.isfile(path):
        print('File not found:', path)
        return

    if name[-4:] == '.cnl':
        print('File might be encrypted.')
        box = libnacl.secret.SecretBox(
            libnacl.encode.hex_decode(
                plyer.keystore.get_key('Λόγῳ', 'conceal')))

        try:
            with open(dirname + '/default.yml') as yc:
                config = yaml.load(yc.read())
            secret = box.decrypt(base64.b64decode(config['key']))
        except FileNotFoundError:
            print('Didn\'t find any configuration file')
            return

        archive = Archive(ConcealIO(
            path, secret, 'r'))
        print('Successfully opened encrypted archive.')
    else:
        archive = Archive(File(path))

    if args.check == 'check':
        check = Check(archive)
        check.run()

if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser()
    parser.add_argument("check", help="Check archive integrity")
    parser.add_argument("-f", "--file", required=True)
    parser.add_argument("-c", "--config")

    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
