"""Server argument parser."""
import argparse


class Parser:
    """Argument parsing class that can be loaded in a container."""

    def __init__(self):
        """Initialize parser."""
        parser = self.parser()
        self.args = parser.parse_args()

    def parser(self):
        """Argument parser configuration."""
        parser = argparse.ArgumentParser()
        parser.add_argument(
            '-l', '--listen',  choices=['local', 'unfollow'],
            help='')
        parser.add_argument(
            'csv',
            help='Path to CSV file with Twitter handles')
        parser.add_argument(
            '-i', '--index', dest='index',
            default=1, type=int,
            help='Index of where to start in CSV file.')
        parser.add_argument(
            '-b', '--background', dest='background',
            default=False, action='store_true',
            help='Will operate in background without disturbing user')
        return parser
