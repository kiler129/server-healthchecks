#!/usr/bin/env bash
# Checks ZFS pool(s) status and returns proper exit code & short summary
#
# By default "zpool status" always exits with 0, as the exit code indicates
# command status and not pool status. This script does just that: uses exit
# code to indicate pool status. You can call it without options to get
# combined status of all pools, or specify just one pool name. The script
# will exit with 1 if any of the pools are not online.
#
# Usage: zpool-status [poolName]
#
# (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset

# We abbreiviate status as the full one for larger pools will be horrendously long
zstatus=$(/sbin/zpool status "$@" | grep -E -e '^\s*?\w+:' | grep -v 'config:' | sed -r -e 's/^(\s+pool:)/\n\1/' | tail +2)
echo "${zstatus}"

# Grep will exit with non-zero if there are no lines NOT having "ONLINE". If this script is
# called without a pool name it will return exit=1 if at least one of the pools is not online
poolsHealthy=0
echo "${zstatus}" | grep -E '^\s+state:\s+' | grep -v -E 'ONLINE$' > /dev/null 1>&2 || poolsHealthy=1

if [[ $poolsHealthy -eq 0 ]]; then exit 1; fi
