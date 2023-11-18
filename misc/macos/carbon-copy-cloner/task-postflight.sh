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
###### CONFIGURATION END - DO NOT EDIT BELOW ######

# Displays error message & script usage help, then exits with error
# Params: [messageToDisplay]
# Prints: error message & help
# Return: always 1
showUsageError () {
    if [[ ! -z ${1+x} ]]; then
      echo -e "Error: $1\n---\n" 1>&2
    fi

    echo "CCC Post-Flight Script" 1>&2
    echo "Usage: $(basename $0) SOURCE DESTINATION EXIT_CODE" 1>&2
    echo -e "\nSee CCC docs for details: https://bombich.com/it/kb/ccc6/performing-actions-before-and-after-backup-task" 1>&2
    exit 1
}

# If CCC decides to add more params this will not fail
if [[ "$#" -lt 3 ]]; then
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
backupExitCode="$3"

# bash doesn't allow mixing variables and ASCII escapes (see https://stackoverflow.com/a/13658950/)
newLn=$'\n'

logOutput=""
if [[ $PING_INC_TASK_LOG -ne 0 ]]; then # fail-safe, i.e. log if not disabled
  computerName=$(networksetup -getcomputername)
  logOutput+="Backup of \"${computerName}\""
  if [[ ! -z "${TASK_NAME}" ]]; then
    logOutput+=" (${TASK_NAME})"
  fi
  if [[ "${backupExitCode}" -ne 0 ]]; then
    logOutput+=" FAILED"
  else
    logOutput+=" finished successfully"
  fi
  logOutput+=" at `date`${newLn}"
  logOutput+="Source: ${backupSource}${newLn}"
  logOutput+="Destination: ${backupDest}${newLn}"
  logOutput+="Exit code: ${backupExitCode}${newLn}"
fi

if [[ -z "${logOutput}" ]]; then
  curl -fsS -m $PING_TIMEOUT --retry $PING_RETRY "${PING_URL}/${backupExitCode}" &> /dev/null
else
  curl -fsS -m $PING_TIMEOUT --retry $PING_RETRY --data-raw "${logOutput}" "${PING_URL}/${backupExitCode}" &> /dev/null
fi
