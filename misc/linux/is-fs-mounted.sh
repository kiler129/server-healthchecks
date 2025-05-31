#!/bin/sh
# Checks whether a filesystem is mounted and can be read & written
#
# This script is useful for monitoring NFS mounts and aids in
# early detection of otherwise-silent failures, even if transient.
#
# Usage: is-fs-mounted mountpoint
#
# (c) Gregory House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o nounset

exit_error () {
  echo "$1" >&2
  exit 1
}

if [ "$#" -ne 1 ] ; then
  exit_error "Usage: $0 mounpoint"
fi

FS_DIR="$1"
TEST_FILE="$FS_DIR/.fs-mountcheck"

if ! mountpoint -q "$FS_DIR"; then
  exit_error "No filesystem mounted at $FS_DIR"
fi

timeNow="$(date)"
echo "$timeNow" > "$TEST_FILE" || exit_error "Failed to create canary file at $TEST_FILE"
grep -q "$timeNow" "$TEST_FILE" || exit_error "Failed to read & compare canary file at $TEST_FILE"
rm "$TEST_FILE" || exit_error "Failed to delete canary file at $TEST_FILE"

echo "Test OK at $timeNow"
exit 0
