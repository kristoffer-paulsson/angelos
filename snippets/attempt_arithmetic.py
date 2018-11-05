import os.path
import sys


from eidon.compressor import ArithmeticCompressor
from eidon.delta import EliasDeltaEncoder, Delta


path = os.path.realpath(
     os.path.dirname(os.path.abspath(sys.argv[0]))+'/../image.png')
with open(path, 'rb') as file:
    input = bytearray(file.read())


#print(len(input))
#encoder = EliasDeltaEncoder()
#encoded = encoder.run(input)
#compressor = ArithmeticCompressor()
#output = compressor.run(encoded)
#print(len(output))

for i in range(1, 257):
    print(i, Delta._gamma(i))
