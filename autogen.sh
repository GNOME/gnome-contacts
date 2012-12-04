#!/bin/sh
mkdir -p m4
autopoint --force
git submodule update --init --recursive
AUTOPOINT='intltoolize --automake --copy' autoreconf -fiv -Wall || exit
./configure --enable-maintainer-mode "$@"
