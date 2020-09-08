#!/bin/bash
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#

install=$(cd $1; pwd)

build_python () {
  local="Python-3.8.5.tgz"
  internal="Python-3.8.5"
  # echo $install; exit

  mkdir -p ./tarball

  if ! [ -f ./tarball/$local ]; then
    curl -o ./tarball/$local "https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz"
  fi

  cd ./tarball
  tar -xzf ./$local
  cd ./$internal

  ./configure --enable-optimization --prefix=$install
  make
  make test
  make install
}

build_python