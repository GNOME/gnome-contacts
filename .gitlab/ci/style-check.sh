#!/usr/bin/env bash

###############################################################################
# JUNIT HELPERS
###############################################################################

JUNIT_REPORT_TESTS_FILE=$(mktemp)

# We need this to make sure we don't send funky stuff into the XML report
function escape_xml() {
  echo "$1" | sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

function append_failed_test_case() {
  test_name="$1"
  test_message="$2"

  test_message_esc="$(escape_xml "$test_message")"
  echo "<testcase name=\"$test_name\"><failure message=\"$test_message_esc\"/></testcase>" >> $JUNIT_REPORT_TESTS_FILE
  echo >&2 "Test '$test_name' failed: $test_message"
}

function append_passed_test_case() {
  test_name="$1"
  commit="$2"

  echo "<testcase name=\"$test_name\"></testcase>" >> $JUNIT_REPORT_TESTS_FILE
}

function generate_junit_report() {
  junit_report_file="$1"
  num_tests=$(cat "$JUNIT_REPORT_TESTS_FILE" | wc -l)
  num_failures=$(grep '<failure' "$JUNIT_REPORT_TESTS_FILE" | wc -l )

  echo Generating JUnit report \"$(pwd)/$junit_report_file\" with $num_tests tests and $num_failures failures.

  cat > $junit_report_file << __EOF__
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="$num_tests" errors="0" failures="$num_failures">
<testsuite name="style-review" tests="$num_tests" errors="0" failures="$num_failures" skipped="0">
$(< $JUNIT_REPORT_TESTS_FILE)
</testsuite>
</testsuites>
__EOF__
}


###############################################################################
# STYLE CHECKS
###############################################################################

TESTNAME="No tabs"
tabs_occurrences="$(fgrep -nR $'\t' src data)"
if [[ -z "$tabs_occurrences" ]]; then
  append_passed_test_case "$TESTNAME"
else
  append_failed_test_case "$TESTNAME" \
    $'Please remove the tabs found at the following places:\n\n'"$tabs_occurrences"
fi


TESTNAME="No trailing whitespace"
trailing_ws_occurrences="$(grep -nri '[[:blank:]]$' src data)"
if [[ -z "$trailing_ws_occurrences" ]]; then
  append_passed_test_case "$TESTNAME"
else
  append_failed_test_case "$TESTNAME" \
    $'Please remove the trailing whitespace at the following places:\n\n'"$trailing_ws_occurrences"
fi


# Generate the report
# and fail this step if any failure occurred
generate_junit_report style-check-junit-report.xml

! grep -q '<failure' style-check-junit-report.xml
exit $?
