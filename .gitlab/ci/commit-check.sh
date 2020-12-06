#!/usr/bin/env bash
#
# commit-check.sh: Performs some basic checks on commit messages
#
# For general recommendations, see https://wiki.gnome.org/Git/CommitMessages

# Source the JUnit helpers
scriptdir="$(dirname "$BASH_SOURCE")"
source "$scriptdir/junit-report.sh"

target_branch="${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-${CI_DEFAULT_BRANCH}}"

# Get the list of commits (hashes) in this branch
git fetch "$CI_MERGE_REQUEST_PROJECT_URL.git" "$target_branch"
branch_point="$(git merge-base HEAD FETCH_HEAD)"
commits="$(git log --format='format:%H' $branch_point..$CI_COMMIT_SHA)"

if [[ -z "$commits" ]]; then
  echo "Commit range empty" >&2
  exit 1
fi

for commit in $commits; do
  commit_msg="$(git show -s --format='format:%B' $commit)"

  # Note: this might seem a bit strict, but remember that we allow this to fail
  # in the CI pipeline (although it will give warnings).
  TESTNAME="Lines shouldn't be too long"
  MAX_LENGTH=75
  too_long_lines="$(echo "$commit_msg" | grep ".\{$(( MAX_LENGTH + 1 ))\}" )"
  if [[ -z "$too_long_lines" ]]; then
    append_passed_test_case "$TESTNAME"
  else
    append_failed_test_case "$TESTNAME" \
      "Commit $commit: Some lines are over $MAX_LENGTH characters:"$'\n\n'"$too_long_lines"
  fi


  # Needed to have nicely working shortlog
  TESTNAME="2nd line should be empty"
  if [[ "$(echo "$commit_msg" | wc -l)" -le 1 ]]; then
    # Commit is just one line long, so we're ok
    append_passed_test_case "$TESTNAME"
  elif [[ -z "$(echo "$commit_msg" | sed -n "2p")" ]]; then
    # 2nd line is empty
    append_passed_test_case "$TESTNAME"
  else
    append_failed_test_case "$TESTNAME" \
      "Commit $commit: Second line is not empty"
  fi
done

# Generate report
generate_junit_report "$CI_JOB_NAME-junit-report.xml" "$CI_JOB_NAME"
check_junit_report "$CI_JOB_NAME-junit-report.xml"
