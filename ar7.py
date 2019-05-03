#!/usr/bin/env python3
"""
Ar7 is a utility to work with Archive7/ConcealIO encrypted archives.

KEY=$(dd if=/dev/urandom bs=1 count=32 2>&1)
"""
from angelos.archive.utility import main


if __name__ == '__main__':
    main()
