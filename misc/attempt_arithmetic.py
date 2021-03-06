"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import os.path
import sys


# from eidon.compressor import ArithmeticCompressor
from eidon.delta import Delta


path = os.path.realpath(
     os.path.dirname(os.path.abspath(sys.argv[0]))+'/../image.png')
with open(path, 'rb') as file:
    input = bytearray(file.read())

print(len(input))
output = Delta.encode(input)
print(len(output))


# for i in range(1, 257):
#    print(i, Delta._gamma(i))
