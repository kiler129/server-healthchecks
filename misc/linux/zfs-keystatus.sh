#!/usr/bin/env bash
# Checks ZFS datasets key statuts and report these with key
# available/unavailable
#
# This tool will check ZFS filesystems (mountable datasets) and
# volumes (zvols/block storage). For their encryption key
# availability. Presence of any fs/volume with its key unavailable
# is treated as an error. If the key is not set (i.e. dataset not
# encrypted) or the key is available, the dataset is printed
# but exit code indicates success. If the system contains no
# encrypted datasets, this fact will be reported in the output
# but it will not be treated as an error, so that this script
# can be easily deployed to all systems, reagrdless of their
# [current] usage of ZFS encryption.
#
# By default this tool will check all datasets, but you can only
# check one by supplying a name as the first argument and it will
# be listed recursively.
#
# Usage: zfs-keystatus [datasetName]
#
# (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset

zstatus=$(/sbin/zfs get -r -o name,value -t filesystem,volume keystatus "$@" | awk '$2 != "-"')
if [[ $(echo "$zstatus" | tail +2) == '' ]]; then
  echo "No encrypted datasets found"
  exit 0
fi

withoutKey=$(echo "$zstatus" | awk '{ print $2 }' | (grep -E '^unavailable$' || true) | wc -l)
if [[ $withoutKey -eq 0 ]]; then
  echo "All encrypted datasets have their key available"
  exit 0
fi

echo "There are $withoutKey encrypted dataset(s) without an available key:"
echo ''
echo "$zstatus"
exit 1
