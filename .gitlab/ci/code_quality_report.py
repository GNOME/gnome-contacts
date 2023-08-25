#!/usr/bin/env python3
#
# Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
#
# SPDX-License-Identifier: GPL-2.0-or-later

import code_climate as cc
import glob
import json
import sys

report = cc.Report()

all_vala_files = list(glob.glob('**/*.vala'))
all_c_files = list(glob.glob('**/*.c'))
all_meson_files = list(glob.glob('**/meson.build'))


for file in all_vala_files:
    with open(file, "r") as f:
        for linenr, line in enumerate(f):
            # if file == "src/contacts-avatar.vala":
            #     print("'%s'" % line)
            if line[:-1].endswith(' '):
                issue = cc.Issue("Trailing Whitespace",
                                 "You have trailing whitespace",
                                 [ cc.Category.STYLE ],
                                 cc.Location(file, (cc.Position(linenr), cc.Position(linenr))))
                report.add_issue(issue)

print(report.to_json())
