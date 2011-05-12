#!/bin/sh
mkdir -p m4
AUTOPOINT='intltoolize --automake --copy' autoreconf -fiv -Wall || exit
./configure --enable-maintainer-mode "$@"
