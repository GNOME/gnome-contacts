#!/bin/bash

set +e

xvfb-run -a -s "-screen 0 1024x768x24" flatpak build app ninja -C _build test

exit_code=$?

python3 .gitlab-ci/meson-junit-report.py \
        --project-name=folks \
        --job-id "${CI_JOB_NAME}" \
        --output "_build/${CI_JOB_NAME}-report.xml" \
        _build/meson-logs/testlog.json

exit $exit_code
