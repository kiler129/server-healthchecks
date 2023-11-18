#!/usr/bin/env bash
# (c) Gregory House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset

############### CONFIGURATION START ###############
PING_URL='http://example.com'

TASK_NAME=''         # optional task name to include in log
PING_TIMEOUT=10      # positive integer; timeout in seconds for the ping call
PING_RETRY=5         # positive integer; how many times to retry ping if it fails
PING_INC_TASK_LOG=1  # 0 or 1; whether to include some log about the task
PING_INC_NET_LOG=1   # 0 or 1; whether to include network information in the log
###### CONFIGURATION END - DO NOT EDIT BELOW ######

# Displays error message & script usage help, then exits with error
# Params: [messageToDisplay]
# Prints: error message & help
# Return: always 1
showUsageError () {
    if [[ ! -z ${1+x} ]]; then
      echo -e "Error: $1\n---\n" 1>&2
    fi

    echo "CCC Pre-Flight Script" 1>&2
    echo "Usage: $(basename $0) SOURCE DESTINATION [DST_IMG_VOL] [DST_IMG]" 1>&2
    echo -e "\nSee CCC docs for details: https://bombich.com/it/kb/ccc6/performing-actions-before-and-after-backup-task" 1>&2
    exit 1
}

# If CCC decides to add more params this will not fail
if [[ "$#" -lt 2 ]]; then
  showUsageError
fi

# Validate ping URL a bit
if [[ "${PING_URL}" != http* ]]; then
    showUsageError "Ping URL \"${PING_URL}\" is invalid: it does not start with http"
fi
if [[ "${PING_URL}" =~ /(start|fail|[0-9]+)/?$ ]]; then
    showUsageError "Ping URL \"${PING_URL}\" is invalid: it should not contain an action (e.g. /start) nor exit code (/<number>)"
fi
if [[ "${PING_URL}" == *"?"* ]]; then
    showUsageError "Ping URL \"${PING_URL}\" is invalid: it should not contain query string"
fi


backupSource="$1"
backupDest="$2"
backupDstImgVol="${3:-}"
backupDstImg="${4:-}"

# bash doesn't allow mixing variables and ASCII escapes (see https://stackoverflow.com/a/13658950/)
newLn=$'\n'
ascTab=$'\t'

logOutput=""
if [[ $PING_INC_TASK_LOG -ne 0 ]]; then # fail-safe, i.e. log if not disabled
  computerName=$(networksetup -getcomputername)
  logOutput+="Backup of \"${computerName}\""
  if [[ ! -z "${TASK_NAME}" ]]; then
    logOutput+=" (${TASK_NAME})"
  fi
  logOutput+=" started at `date`${newLn}"
  logOutput+="Source: ${backupSource}${newLn}"
  logOutput+="Destination: ${backupDest}${newLn}"

  if [[ ! -z "${backupDstImg}" ]]; then
    logOutput+="Destination image: ${backupDstImg}${newLn}"
  fi

  if [[ ! -z "${backupDstImgVol}" ]]; then
    logOutput+="Destination img. volume: ${backupDstImgVol}${newLn}"
  fi
fi

if [[ $PING_INC_NET_LOG -eq 1 ]]; then  # fail-safe, i.e. log if not disabled
  airportSSID=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | \
               sed -n "s/^[[:space:]]*SSID:[[:space:]]\(.*\)$/\1/p")
  defaultRoutes=$(netstat -rn | grep -E '^default' | tr -s ' ' | cut -d' ' -f2,4 | column -t | sed -e 's/^/\t\t/')

  logOutput+="${newLn}Network configuration${newLn}"
  logOutput+="${ascTab}AirPort SSID: ${airportSSID}${newLn}"
  logOutput+="${ascTab}Default routes:${newLn}${defaultRoutes}${newLn}"
fi

if [[ -z "${logOutput}" ]]; then
  curl -fsS -m $PING_TIMEOUT --retry $PING_RETRY "${PING_URL}/start" &> /dev/null
else
  curl -fsS -m $PING_TIMEOUT --retry $PING_RETRY --data-raw "${logOutput}" "${PING_URL}/start" &> /dev/null
fi
