#!/bin/sh
AUTOPOINT='intltoolize --automake --copy' autoreconf -fiv -Wall || exit
./configure --enable-maintainer-mode "$@"
