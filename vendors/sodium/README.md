# Sodium
The Sodium library is a NaCL implementation that is portable and should be the main source of encryption in the Angelos project.

## Download
1. Download the latest stable libsodium tarball.
2. Expand the sources into the libsodium-stable folder.
3. Move the libsodium-stable folder inside this folder.

https://download.libsodium.org/libsodium/releases/libsodium-1.0.18-stable.tar.gz

## Compile
1. Go to ```vendors/sodium/libsodium-stable``` folder.
2. Configure the sources. ```./configure```
3. Compile and check the result. ```make && make check```

# Install
Install the libraries using the project folder as root. 

```make install DESTDIR=$(cd ../../../; pwd)```
