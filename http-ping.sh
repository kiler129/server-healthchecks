#!/usr/bin/env bash
# (c) Gregory House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset
cd "$(dirname "$0")"

# Defaults
okHttpCodes="200,204"
maxTime=5
maxRetry=0

# Script options
version="2023121601"
homeUrl="https://github.com/kiler129/server-healthchecks"
updateUrl="https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-ping.sh"

# Displays script usage
# WARNING: uses global variables:
#   - oktHttpCodes
#   - version
#   - homeUrl
# Params: <none>
# Prints: usage text
# Return: <none>
showUsage () {
    local _baseScript=$(basename $0)
    echo "HTTP Ping v$version" 1>&2
    echo "Usage: $_baseScript [OPTION]... CHECK_URL" 1>&2
    echo 1>&2
    echo "Options:" 1>&2
    echo "  -c <codes>    List of comma-separated HTTP codes considered successful" 1>&2
    echo "                Default: $okHttpCodes" 1>&2
    echo "  -g <pattern>  Consider success only if grep in pattern mode (-e) DOES match the output." 1>&2
    echo "                For this option to work your system must provide grep/BusyBox with grep." 1>&2
    echo "                The output is checked only if HTTP code indicates success." 1>&2
    echo "  -G <pattern>  Consider success only if grep in pattern mode (-e) DOES NOT match the output." 1>&2
    echo "                For this option to work your system must provide grep/BusyBox with grep." 1>&2
    echo "                The output is checked only if HTTP code indicates success." 1>&2
    echo "  -p            Print output of the request"
    echo "  -i            HTTPS insecure mode - ignores SSL errors"
    echo "  -m $maxTime          Maximum amount of time (s) to wait for HTTP server to respond" 1>&2
    echo "  -r $maxRetry          How many times (up to -m) check should repeat if it fails" 1>&2
    echo 1>&2
    echo "Special:" 1>&2
    echo "  -u            Self-update this script. This option must be used alone." 1>&2
    echo "  -h            Shows this help text"
    echo 1>&2
    echo "Found a bug? Have a question? Head out to $homeUrl"
}

# Displays error message & script usage help, then exits with error
# Params: messageToDisplay
# Prints: error message & help
# Return: always 1
showUsageError () {
    echo -e "Error: $1\n---\n" 1>&2
    showUsage "$0"
    exit 1
}

# Queries a given url and returns content & http code
# Params: url checkSsl timeout retry &responseCode &responseContent &curlErrors
# Prints: <none>
# Return: <none>
callUrl () {
  local _url="$1"
  local _checkSsl="$2"
  local _timeout="$3"
  local _retry="$4"
  local -n _httpCode=$5
  local -n _response=$6
  local -n _errors=$7

  local _curlArgs=(-s -S -L -o - -w '%{stderr}\n%{http_code}' --url "$_url")
  if [[ "$_checkSsl" -eq 0 ]]; then
    _curlArgs+=(--insecure)
  fi
  if [[ "$_timeout" -gt 0 ]]; then
    _curlArgs+=(-m "$_timeout")
  fi
  if [[ "$_retry" -gt 0 ]]; then
    _curlArgs+=(--retry "$_retry")
  fi

  # This is an idea from https://stackoverflow.com/a/59592881
  # It ignores curl exit code as we will determine failure based on http code later
  local _curlStdErr=""
  {
      IFS=$'\n' read -r -d '' _curlStdErr;
      IFS=$'\n' read -r -d '' _response;
  } < <((printf '\0%s\0' "$(curl "${_curlArgs[@]}")" 1>&2) 2>&1)

  _errors=$(sed '$d' <<< "$_curlStdErr")
  _httpCode=$(sed -n '$p' <<< "$_curlStdErr")
}

# Updates this script from the update URL
# WARNING: this function depends on global variable "updateUrl"
# Params: <none>
# Prints: logs
# Return: direct exit 0 on success, or 1 on failure
selfUpdate () {
    local _baseScript=$(basename $0)
    echo "Updating $_baseScript from $updateUrl"
    if [[ ! -w "$_baseScript" ]]; then
        echo "Script file is not writeable!"
        exit 1
    fi

    curVersion=$(cat "$_baseScript")
    echo "Downloading latest version..."
    newVersion=$(curl -fS "$updateUrl")
    if [[ "$curVersion" == "$newVersion" ]]; then
        echo "Current version is already up to date - nothing to do"
        exit 0
    fi

    local _previous="${_baseScript}_previous"
    echo "New version detected - backing up & updating"
    cp "$_baseScript" "$_previous"
    chmod -x "$_previous"
    set +o noclobber
    echo "$newVersion" >| "$_baseScript"
    chmod +x "$_baseScript"

    echo "Update successful. New version installed."
    exit 0
}

printOutput=0
checkSsl=0
outputMatch=''
outputNotMatch=''
while getopts ':c:g:G:pim:r:uh' opt; do
    case "$opt" in
        c) okHttpCodes="$OPTARG" ;;
        g) outputMatch="$OPTARG" ;;
        G) outputNotMatch="$OPTARG" ;;
        p) printOutput=1 ;;
        i) checkSsl=0 ;;
        m) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for request timeout (-m): \"$OPTARG\" is not an number"
           fi
           maxTime=$OPTARG ;;
        r) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for request max retries (-r): \"$OPTARG\" is not a number"
           fi
           maxRetry=$OPTARG ;;
        u) if [[ $# -gt 1 ]]; then
               # this is a safety measure to prevent accidental invocations with -u somewhere
               showUsageError "Self-update (-u) must NOT be called with any other arguments"
           fi
           selfUpdate ;;
        h) showUsage
           exit 0 ;;
        ?) showUsageError "Invalid command option \"-${OPTARG}\" specified" ;;
    esac
done
shift "$(($OPTIND -1))"
if [[ $# -lt 1 ]]; then
    showUsageError "Check URL is mandatory"
fi

checkUrl="$1"
if [[ "$checkUrl" != http* ]]; then
    showUsageError "Check URL \"$checkUrl\" is invalid: it does not start with http"
fi

# Split http codes into array, being flexible about comma/spaces/comma+space
okHttpCodesArr=()
IFS=', ' read -r -a okHttpCodesArr <<< "$okHttpCodes"

echo "Requesting $checkUrl"
response=""
httpCode=""
errors=""
callUrl "$checkUrl" $checkSsl $maxTime $maxRetry httpCode response errors

### First, determine if HTTP request status on the basis of metadata
if [[ " ${okHttpCodesArr[*]} " =~ " ${httpCode} " ]]; then # the HTTP code indicates no error
  echo "HTTP request succeeded with code $httpCode"
  exitCode=0
elif [[ "$httpCode" -eq "000" ]]; then
  if [[ -z "$errors" ]]; then
    echo "Request failed without a response - no additional details are available"
  else
    echo "Request failed without a response" # errors printed below for consistency
  fi
  exitCode=126
else
  echo "Request failed with HTTP code $httpCode"
  exitCode=1
fi

### Next, take care of content matching (is possible still)
if [[ ! -z "${outputMatch}" ]] && [[ $exitCode -eq 0 ]]; then # positive output matching requested & possible
  if echo "${response}" | grep -q -e "${outputMatch}" ; then # output matched positive regex => pass
    echo "The response contents matched expected pattern \"${outputMatch}\""
    exitCode=0
  else
    echo "HTTP ping failed: the $httpCode indicated success but the contents did not match expected pattern \"${outputMatch}\""
    exitCode=1
  fi
fi

if [[ ! -z "${outputNotMatch}" ]] && [[ $exitCode -eq 0 ]]; then # negative output matching requested & possible
  if ! echo "${response}" | grep -q -e "${outputNotMatch}" ; then # output matched negative regex => fail
    echo "The response contents did not match prohibited pattern \"${outputNotMatch}\""
    exitCode=0
  else
    echo "HTTP ping failed: the $httpCode indicated success but the contents matched prohibited pattern \"${outputNotMatch}\""
    exitCode=1
  fi
fi

# this can happen even if request succeeded (e.g. warning about SSL etc)
if [[ ! -z "$errors" ]]; then
  echo "Additional information: ${errors}"
fi

if [[ "$printOutput" -eq 1 ]] && [[ $exitCode -ne 126 ]]; then
  if [[ -z "$response" ]]; then
    echo "Server returned no response"
  else
    echo "Server response: ${response}" # for most apps it's probably a one-liner like "OK"
  fi
fi
exit $exitCode
