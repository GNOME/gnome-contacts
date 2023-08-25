#!/usr/bin/env python3
#
# Copyright (C) 2023 Niels De Graef <nielsdegraef@gmail.com>
#
# SPDX-License-Identifier: GPL-2.0-or-later

import json
from typing import List, Optional, Tuple
from enum import Enum

class Category(Enum):
    BUG_RISK = "Bug Risk"
    CLARITY = "Clarity"
    COMPATIBILITY = "Compatibility"
    COMPLEXITY = "Complexity"
    DUPLICATION = "Duplication"
    PERFORMANCE = "Performance"
    SECURITY = "Security"
    STYLE = "Style"

class Severity(Enum):
    INFO = "info"
    MINOR = "minor"
    MAJOR = "major"
    CRITICAL = "critical"
    BLOCKER = "blocker"

class Content:

    def __init__(self, body: str):
        self.body = body

    def to_dict(self):
        return {
            "body": self.body,
        }

class Position:
    def __init__(self, line: int, column: int=None):
        self.line = line
        self.column = column

class Location:

    def __init__(self, path: str, positions: Tuple[Position, Position]):
        self.path = path
        self.positions = positions

    def to_dict(self):
        result = {
            "path": self.path,
        }

        if self.positions[0].column is None:
            result["lines"] = {
                "begin": self.positions[0].line,
                "end": self.positions[1].line,
            }
        else:
            result["positions"] = {
                "begin": { "line": self.positions[0].line, "column": self.positions[0].column },
                "end": { "line": self.positions[1].line, "column": self.positions[1].column },
            }

        return result

class Trace:

    def __init__(self, locations: List[Location], stacktrace: bool=False):
        self.locations = locations
        self.stacktrace = stacktrace

    def to_dict(self):
        return {
            "locations": self.path,
            "stacktrace": self.stacktrace,
        }

class Issue:

    def __init__(self, name: str, description: str, categories: List[Category], location: Location,
                 content: Optional[str]=None, trace: Optional[Trace]=None, remediation_points: Optional[int]=None,
                 severity: Optional[Severity]=None, fingerprint: Optional[str] = None):
        self.name = name
        self.description = description
        self.categories = categories
        self.location = location
        self.content = content
        self.trace = trace
        self.remediation_points = remediation_points
        self.severity = severity
        self.fingerprint = fingerprint

    def to_dict(self):
        result = {
            "type": "issue",
            "check_name": self.name,
            "description": self.description,
            "categories": [str(c.value) for c in self.categories],
            "location": self.location.to_dict(),
        }

        if self.content:
            result["content"] = self.content
        if self.trace:
            result["trace"] = self.trace
        if self.remediation_points:
            result["remediation_points"] = self.remediation_points
        if self.severity:
            result["severity"] = self.severity
        if self.fingerprint:
            result["fingerprint"] = self.fingerprint

        return result

class Report:

    def __init__(self):
        self.issues = []

    def add_issue(self, issue: Issue):
        self.issues.append(issue)

    def to_dicts(self):
        return [i.to_dict() for i in self.issues]

    def to_json(self):
        return json.dumps(self.to_dicts())
