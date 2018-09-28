#!/bin/sh

SRC_DIR=../src

echo "$(dirname "$BASH_SOURCE")"
uncrustify -c build-aux/uncrustify.cfg --no-backup src/*.vala
