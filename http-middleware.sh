#!/usr/bin/env bash
# (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset
cd "$(dirname "$0")"

version="2023020101"
homeUrl="https://github.com/kiler129/server-healthchecks"
httpPingUrl="https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-ping.sh"
withHealthcheckUrl="https://raw.githubusercontent.com/kiler129/server-healthchecks/main/with-healthcheck.sh"

# Displays script usage
# WARNING: uses global variables:
#   - homeUrl
# Params: <none>
# Prints: usage text
# Return: <none>
showUsage () {
    local _baseScript=$(basename $0)
    echo "HTTP Middleware v$version" 1>&2
    echo "Usage: $_baseScript [OPTION]..." 1>&2
    echo 1>&2
    echo "Options:" 1>&2
    echo "  -e <file>    File with a list environment variables to source (see help below)" 1>&2
    echo "  -h           Shows this help text"
    echo 1>&2
    echo "Configuration reference:" 1>&2
    echo "This script is controlled with dynamic environment variables, as it's meant to" 1>&2
    echo "be mostly used with docker. When used without, the cleanest way is to save" 1>&2
    echo "variables in a separate file (e.g. \"envs\") and call this script with -e option." 1>&2
    echo 1>&2
    echo "Static variables:" 1>&2
    echo "  MIDDLEWARE_CHECK_MAX=99 - number of dynamic variables scanned (you can leave" 1>&2
    echo "                            it at 99 if you don't have >99 checks)" 1>&2
    echo "  MIDDLEWARE_DEBUG=0      - enables with-healthcheck util verbose mode and" 1>&2
    echo "                            forces printing of http-ping output" 1>&2
    echo 1>&2
    echo "Dynamic variables can be set multiple times with a different number to add more" 1>&2
    echo "checks. Replace # in each variable name listed below with a number between 0 and" 1>&2
    echo "MIDDLEWARE_CHECK_MAX. They don't need to be consecutive. For example to set" 1>&2
    echo "check interval for first check you will use \"CHECK_INTERVAL_1=5m\"." 1>&2
    echo 1>&2
    echo "Available dynamic variables: (those listed with values are optional)" 1>&2
    echo " CHECK_URL_#              - REQUIRED; http(s) URL to query" 1>&2
    echo " PING_URL_#               - REQUIRED; url to ping service as accepted by" 1>&2
    echo "                            with-healthcheck util" 1>&2
    echo " CHECK_INTERVAL_#=15m     - How ofter to visit CHECK_URL; accepts suffixes" 1>&2
    echo "                            s/m/h/d for seconds/minutes/hours/days." 1>&2
    echo "                            Fractions are supported but you can't combine" 1>&2
    echo "                            multiple different suffixes" 1>&2
    echo " CHECK_OK_CODES_#=<val>   - Comma-separated list of HTTP codes considered" 1>&2
    echo "                            as \"success\" for CHECK_URL. Default value " 1>&2
    echo "                            determined by http-ping.sh" 1>&2
    echo " CHECK_INSECURE_#=0       - Enables insecure HTTPS mode, in which SSL errors" 1>&2
    echo "                            like self-signed certs are ignored" 1>&2
    echo " CHECK_TIMEOUT_#=<num>    - Time in seconds. Total time allotted for the" 1>&2
    echo "                            CHECK_URL response. The time includes ALL" 1>&2
    echo "                            retry attempts. Default value determined by" 1>&2
    echo "                            http-ping.sh" 1>&2
    echo " CHECK_RETRY_#=<num>      - How many times to retry if calling CHECK_URL fails" 1>&2
    echo "                            for reasons other than response code being outside" 1>&2
    echo "                            of CHECK_OK_CODES. This usually includes DNS and" 1>&2
    echo "                            connection timeouts." 1>&2
    echo "                            Default value determined by http-ping.sh" 1>&2
    echo " CHECK_INC_CONTENT_#=1    - Whether to include contents returned by CHECK_URL" 1>&2
    echo "                            in the ping message. This option has no" 1>&2
    echo "                            effect if PING_INC_LOG_#=0, as the generated output" 1>&2
    echo "                            from http-ping will be discarded." 1>&2
    echo " PING_TIMEOUT_#=<num>     - Time in seconds. Total time allotted for the" 1>&2
    echo "                            PING_URL response. The time includes ALL retry" 1>&2
    echo "                            attempts. Default value determined by" 1>&2
    echo "                            with-healthcheck.sh" 1>&2
    echo " PING_RETRY_#=<num>       - How many times to retry if ping submission to" 1>&2
    echo "                            PING_URL fails. The failure can be for any reason." 1>&2
    echo "                            Default value determined by with-healthcheck.sh" 1>&2
    echo " PING_INC_LOG_#=1         - Whether the ping should include http-ping.sh logs." 1>&2
    echo "                            Disabling this will also inherently disables logging" 1>&2
    echo "                            of the response content (see CHECK_INC_CONTENT)." 1>&2
    echo 1>&2
    echo "Found a bug? Have a question? Head out to $homeUrl"
}

# Locates a named tool
# Params: toolName downloadUrl
# Prints: executable path to stdout, or error messages if tool not found to stderr
# Return: 0 on success, 1 on failure
findTool () {
  local _search=("./$1.sh" "./$1" "$1.sh" "$1")
  for toolPath in "${_search[@]}"
  do
    if [[ -x "$toolPath" ]]; then
      echo "$toolPath"
      return 0
    fi
  done

  echo "Failed to find executable \"$1\" utility (tried: ${_search[*]})" 1>&2
  echo "You can download it from $2" 1>&2
  return 1
}

while getopts ':e:h' opt; do
    case "$opt" in
        e) source "${OPTARG}" ;;
        h) showUsage
           exit 0 ;;
        ?) showUsageError "Invalid command option \"${OPTARG}\" specified" ;;
    esac
done

loopMax="${MIDDLEWARE_CHECK_MAX:-99}"
debugMode="${MIDDLEWARE_DEBUG:-0}"
httpPing=$(findTool "http-ping" "$httpPingUrl")
withHealthcheck=$(findTool "with-healthcheck" "$withHealthcheckUrl")

# normally everything in bash starts with 1, but we're normal and check 0 too ;)
jobsFound=0
for((i=0; i<=$loopMax; i++)); do
  checkUrl="CHECK_URL_$i"
  pingUrl="PING_URL_$i"
  if [[ -z "${!checkUrl-}" ]] || [[ -z "${!pingUrl-}" ]]; then
    continue
  fi
  jobsFound+=1

  withHealthcheckArgs=("${withHealthcheck}" -T -E -X)
  httpPingArgs=("${httpPing}")
  if [[ $debugMode -eq 1 ]]; then withHealthcheckArgs+=(-p -v); fi

  pingIncLog="PING_INC_LOG_$i"
  pingTimeout="PING_TIMEOUT_$i"
  pingkRetry="PING_RETRY_$i"
  checkOkCodes="CHECK_OK_CODES_$i"
  checkIncContent="CHECK_INC_CONTENT_$i"
  checkInsecure="CHECK_INSECURE_$i"
  checkTimeout="CHECK_TIMEOUT_$i"
  checkkRetry="CHECK_RETRY_$i"
  checkInterval="CHECK_INTERVAL_$i"

  if [[ "${!pingIncLog-1}" -ne 1 ]]; then withHealthcheckArgs+=(-D); fi
  if [[ ! -z "${!pingTimeout-}" ]]; then withHealthcheckArgs+=(-m "${!pingTimeout}"); fi
  if [[ ! -z "${!pingkRetry-}" ]]; then withHealthcheckArgs+=(-r "${!pingkRetry}"); fi
  if [[ ! -z "${!checkOkCodes-}" ]]; then httpPingArgs+=(-c "${!checkOkCodes}"); fi
  if [[ "${!checkIncContent-1}" -eq 1 ]]; then httpPingArgs+=(-p); fi
  if [[ "${!checkInsecure-0}" -eq 1 ]]; then httpPingArgs+=(-i); fi
  if [[ ! -z "${!checkTimeout-}" ]]; then httpPingArgs+=(-m "${!checkTimeout}"); fi
  if [[ ! -z "${!checkkRetry-}" ]]; then httpPingArgs+=(-r "${!checkkRetry}"); fi
  withHealthcheckArgs+=("${!pingUrl}")
  httpPingArgs+=("${!checkUrl}")

  checkInterval=${!checkInterval-"15m"}
  (
    echo "Job #$i started"
    if [[ $debugMode -eq 1 ]]; then
      echo "Command: ${withHealthcheckArgs[@]}" "${httpPingArgs[@]}"
    fi
    while :; do
      exit=0
      "${withHealthcheckArgs[@]}" "${httpPingArgs[@]}" 2>&1 || exit=$?
      if [[ $exit -ne 0 ]]; then echo "WARNING: the healthcheck script failed!"; fi

      sleep "$checkInterval"
    done
  ) | sed "s/^/[Job#$i] /" &
done

if [[ $jobsFound -eq 0 ]]; then
  showUsage
  exit 1
fi

wait $(jobs -rp)
echo "All jobs terminated!"
