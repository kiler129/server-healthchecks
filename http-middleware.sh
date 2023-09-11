#!/usr/bin/env bash
# (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset
cd "$(dirname "$0")"

version="2023091007"
homeUrl="https://github.com/kiler129/server-healthchecks"
updateUrl="https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-middleware.sh"
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
    echo "  -u           Self-update this script. This option must be used alone." 1>&2
    echo "  -h           Shows this help text" 1>&2
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
    echo "  SPREAD_JITTER=10        - adds a random wait between 0 and number of seconds" 1>&2
    echo "                            specified before each job is FIRST executed, to minimize" 1>&2
    echo "                            thundering herd problem (i.e. self-DoS). Set to 0 to disable." 1>&2
    echo 1>&2
    echo "Dynamic variables can be set multiple times with a different number to add more" 1>&2
    echo "checks. Replace # in each variable name listed below with a number between 0 and" 1>&2
    echo "MIDDLEWARE_CHECK_MAX. They don't need to be consecutive. For example to set" 1>&2
    echo "check interval for first check you will use \"CHECK_INTERVAL_1=5m\"." 1>&2
    echo 1>&2
    echo "Available dynamic variables: (those listed with values are optional)" 1>&2
    echo "  CHECK_URL_#                      - REQUIRED; http(s) URL to query" 1>&2
    echo "  PING_URL_#                       - REQUIRED; url to ping service as accepted by" 1>&2
    echo "                                     with-healthcheck util." 1>&2
    echo "  CHECK_INTERVAL_#=15m             - How ofter to visit CHECK_URL; accepts suffixes" 1>&2
    echo "                                     s/m/h/d for seconds/minutes/hours/days." 1>&2
    echo "                                     Fractions are supported but you can't combine" 1>&2
    echo "                                     multiple different suffixes." 1>&2
    echo "  CHECK_OK_CODES_#=<val>           - Comma-separated list of HTTP codes considered" 1>&2
    echo "                                     as \"success\" for CHECK_URL. Default value " 1>&2
    echo "                                     determined by \"http-ping\" if not set." 1>&2
    echo "  CHECK_MATCH_CONTENT_#=<pattern>  - Ensures returned request content matches \"grep -e\"" 1>&2
    echo "                                     pattern specified. Contents will only be matched on" 1>&2
    echo "                                     \"successful\" HTTP codes." 1>&2
    echo "  CHECK_INSECURE_#=0               - Enables insecure HTTPS mode, in which SSL errors" 1>&2
    echo "                                     like self-signed certs are ignored" 1>&2
    echo "  CHECK_TIMEOUT_#=<num>            - Time in seconds. Total time allotted for the" 1>&2
    echo "                                     CHECK_URL response. The time includes ALL" 1>&2
    echo "                                     retry attempts. Default value determined by" 1>&2
    echo "                                     \"http-ping\" if not set." 1>&2
    echo "  CHECK_RETRY_#=<num>              - How many times to retry if calling CHECK_URL fails" 1>&2
    echo "                                     for reasons other than response code being outside" 1>&2
    echo "                                     of CHECK_OK_CODES. This usually includes DNS and" 1>&2
    echo "                                     connection timeouts. Default value determined by" 1>&2
    echo "                                     \"http-ping\" if not set." 1>&2
    echo "  CHECK_FAILURE_THRESHOLD_#=1      - How many times the check has to fail before the failure " 1>&2
    echo "                                     is reported to PING_URL. By default, which is recommended" 1>&2
    echo "                                     in most cases, the threshold is 1; i.e. failures are reported" 1>&2
    echo "                                     instantly. Setting this value >1 will cause success to be" 1>&2
    echo "                                     reported instantly, while a failure signals will start to" 1>&2
    echo "                                     be delivered only after configured number of consecutive" 1>&2
    echo "                                     failures. Subsequent failures will be delivered without a" 1>&2
    echo "                                     delay, until the counter is reset with array successful" 1>&2
    echo "                                     check. The grace period configured for the ping server must" 1>&2
    echo "                                     be configured to account for the threshold-introduced delay." 1>&2
    echo "                                     When this option is used unexpected failures of \"with-healthcheck\"" 1>&2
    echo "                                     cannot be distinguished from true HTTP endpoint failures." 1>&2
    echo "  CHECK_INC_CONTENT_#=1            - Whether to include contents returned by CHECK_URL" 1>&2
    echo "                                     in the ping message. This option has no" 1>&2
    echo "                                     effect if PING_INC_LOG_#=0, as the generated output" 1>&2
    echo "                                     from \"http-ping\" will be discarded." 1>&2
    echo "  PING_TIMEOUT_#=<num>             - Time in seconds. Total time allotted for the" 1>&2
    echo "                                     PING_URL response. The time includes ALL retry" 1>&2
    echo "                                     attempts. Default value determined by" 1>&2
    echo "                                     \"with-healthcheck\" if not set." 1>&2
    echo "  PING_RETRY_#=<num>               - How many times to retry if ping submission to" 1>&2
    echo "                                     PING_URL fails. The failure can be for any reason." 1>&2
    echo "                                     Default value determined by with-healthcheck.sh" 1>&2
    echo "  PING_INC_LOG_#=1                 - Whether the ping should include \"http-ping\" logs." 1>&2
    echo "                                     Disabling this will also inherently disables logging" 1>&2
    echo "                                     of the response content (see CHECK_INC_CONTENT)." 1>&2
    echo 1>&2
    echo "Default values for dynamic variables:" 1>&2
    echo "  Every optional dynamic variable (i.e. not CHECK_URL_# nor PING_URL_#) can have have a default" 1>&2
    echo "  value assigned. It can be done by setting an environment variable with the same name, but " 1>&2
    echo "  without numeric suffix (e.g. CHECK_TIMEOUT=10)." 1>&2
    echo "  The explicit value set for a given instance (e.g. CHECK_TIMEOUT_0=2) has a higher priority" 1>&2
    echo "  than the default for all instances (e.g. CHECK_TIMEOUT=10). The external defaults are only used" 1>&2
    echo "  when neither value for the given instance nor default are set (e.g. \"http-ping\" default timeout)." 1>&2
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

# Resolves value from the config environment variable into a local variable. The result will be set to a variable named
# passed by reference in the first parameter. If neither index-specific nor default variables are available the
# "placeholder" value is used (by default empty string)
#
# Params: localVariableName configEnvName iterationIndex [placeholder='']
# Prints: logs if debug
# Returns: <none>
resolveConfigValue () {
  local -n result=$1
  local iterationEnv="$2_$3"
  result="${!iterationEnv:-${!2:-${4-}}}"

  if [[ $debugMode -eq 1 ]]; then
    echo -e "Resolved \"$1\"\t=>\t\"$result\"\t|\t$iterationEnv=${!iterationEnv:-<null>} / $2=${!2:-<null>} / placeholder=${4-<unset>}"
  fi
}

while getopts ':e:uh' opt; do
    case "$opt" in
        e) source "${OPTARG}" ;;
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

loopMax="${MIDDLEWARE_CHECK_MAX:-99}"
debugMode="${MIDDLEWARE_DEBUG:-0}"
spreadJitter="${SPREAD_JITTER:-10}"
httpPing=$(findTool "http-ping" "$httpPingUrl")
withHealthcheck=$(findTool "with-healthcheck" "$withHealthcheckUrl")

# normally everything in bash starts with 1, but we're normal and check 0 too ;)
jobsFound=0
for((i=0; i<=$loopMax; i++)); do
  checkUrl="CHECK_URL_$i"
  pingUrl="PING_URL_$i"
  if [[ -z "${!checkUrl-}" ]] || [[ -z "${!pingUrl-}" ]]; then
    if [[ ! -z "${!checkUrl-}" ]] || [[ ! -z "${!pingUrl-}" ]]; then
      # this is a common mistake when copy-pasting blocks ;)
      echo "WARNING: both CHECK_URL_$i and PING_URL_$i are required, but only one of them was found - skipping $i"
    fi
    continue
  fi
  jobsFound+=1

  withHealthcheckArgs=("${withHealthcheck}" -T -E)
  failureCounter=0 # will count up; can go above $failureThreshold (for fault-tolerant mode)
  httpPingArgs=("${httpPing}")
  if [[ $debugMode -eq 1 ]]; then withHealthcheckArgs+=(-p -v); fi

  # This cannot be done without intermediates (unless eval is utilized), as bash doesn't allow indirection with
  # composite variable. The best compromise is probably using a function (even if slow-ish).
  resolveConfigValue checkInterval         CHECK_INTERVAL          $i   '15m'
  resolveConfigValue checkOkCodes          CHECK_OK_CODES          $i
  resolveConfigValue checkMatchContent     CHECK_MATCH_CONTENT     $i
  resolveConfigValue checkInsecure         CHECK_INSECURE          $i   0
  resolveConfigValue checkTimeout          CHECK_TIMEOUT           $i
  resolveConfigValue checkRetry            CHECK_RETRY             $i
  resolveConfigValue checkFailureThreshold CHECK_FAILURE_THRESHOLD $i   1
  resolveConfigValue checkIncContent       CHECK_INC_CONTENT       $i   1
  resolveConfigValue pingTimeout           PING_TIMEOUT            $i
  resolveConfigValue pingRetry             PING_RETRY              $i
  resolveConfigValue pingIncLog            PING_INC_LOG            $i   1

  if [[ -n "$checkOkCodes" ]];      then httpPingArgs+=(-c "$checkOkCodes"); fi
  if [[ -n "$checkMatchContent" ]]; then httpPingArgs+=(-g "$checkMatchContent"); fi
  if [[ "$checkInsecure" -eq 1 ]];  then httpPingArgs+=(-i); fi
  if [[ -n "$checkTimeout" ]];      then httpPingArgs+=(-m "$checkTimeout"); fi
  if [[ -n "$checkRetry" ]];        then httpPingArgs+=(-r "$checkRetry"); fi
  if [[ "$checkFailureThreshold" == '1' ]]; then # deliberate lexical comparison to avoid crashes with e.g. "3a" value
    # command output should affect "with-healthcheck" exit code only in failure-tolerant mode, in order to detect
    # potential unexpected "with-healthcheck" crashes. When fault-tolerance is desired, there isn't a practical way
    # to distinguish these two
    withHealthcheckArgs+=(-X)
  elif [[ ! "$checkFailureThreshold" =~ ^[0-9]$ ]] || [[ "$checkFailureThreshold" -le 0 ]]; then
    echo "Check failure threshold must be a positive integer (got \"$checkFailureThreshold\" for job #$i)"
    showUsage
    exit 1
  fi
  if [[ "$checkIncContent" -eq 1 ]]; then httpPingArgs+=(-p); fi
  if [[ -n "$pingTimeout" ]];        then withHealthcheckArgs+=(-m "$pingTimeout"); fi
  if [[ -n "$pingRetry" ]];          then withHealthcheckArgs+=(-r "$pingRetry"); fi
  if [[ "$pingIncLog" -ne 1 ]];      then withHealthcheckArgs+=(-D); fi
  httpPingArgs+=("${!checkUrl}")

  trap '{ echo -e "\nMiddleware interrupted. Killing all jobs..." ; kill $(jobs -p) 2>/dev/null; }' EXIT
  (
    trap "{ echo 'Terminated via parent EXIT'; exit; }" EXIT

    if [[ $spreadJitter -gt 0 ]]; then
      jobJitter=$(( $RANDOM % ( $spreadJitter + 1 ) ))
      echo "Job #$i will start in $jobJitter seconds to mitigate thundering herd"
      sleep $jobJitter
    fi

    echo "Job #$i started"
    if [[ $debugMode -eq 1 ]]; then
      echo "Command base: ${withHealthcheckArgs[@]}" "${!pingUrl}" "${httpPingArgs[@]}"
    fi
    while :; do
      exit=0
      # If we can withstand >1 failure (i.e. fault-tolerance mode enabled and within threshold limits still) we add
      # "-s" to the "with-healthcheck" to prevent it from pinging with failures. Otherwise
      if [[ $(( $checkFailureThreshold - $failureCounter )) -gt 1 ]]; then
        if [[ $debugMode -eq 1 ]]; then
          echo "Running with failure tolerance: failed $failureCounter times so far (will report at $checkFailureThreshold)"
        fi
        "${withHealthcheckArgs[@]}" -s "${!pingUrl}" "${httpPingArgs[@]}" 2>&1 || exit=$?
      else # either failure tolerance is disabled (threshold=1) OR counter indicates threshold-1 failures already
        # always show the info message in debug mode, but also show it in non-debug when the job failed after threshold
        if [[ $checkFailureThreshold -gt 1 ]]; then
          echo "Running in fault-tolerant mode: failed $failureCounter times so far; no tolerance left (threshold=$checkFailureThreshold)"
        elif [[ $debugMode -eq 1 ]]; then
          echo "Running command w/o failure silencing"
        fi
        "${withHealthcheckArgs[@]}" "${!pingUrl}" "${httpPingArgs[@]}" 2>&1 || exit=$?
      fi

      if [[ $exit -eq 0 ]]; then
        failureCounter=0
      # fault-tolerance mode is disabled => it's the script error
      elif [[ $checkFailureThreshold -eq 1 ]]; then echo "WARNING: the healthcheck script failed w/code=$exit";
      else ((++failureCounter)); fi

      exit=0
      sleep "$checkInterval" &> /dev/null || exit=$?
      if [[ $exit -ne 0 ]]; then
        echo "WARNING: \"sleep $checkInterval\" command failed (exit=$exit). Mostly likely you're using a VERY outdated"
        echo "         shell that doesn't support time suffixes (e.g. bash on macOS)."
        echo "         Either upgrade your shell or specify CHECK_INTERVAL_# in seconds, "
        echo "         without a suffixes (e.g. CHECK_INTERVAL_0=5m => CHECK_INTERVAL_0=300)."
        echo "Forcing 5 minutes wait as a workaround now." # this is so we don't hammer service in a loop
        sleep 300
      fi
    done
  ) | sed -u "s/^/[Job#$i] /" &
done

if [[ $jobsFound -eq 0 ]]; then
  showUsage
  exit 1
fi

wait $(jobs -rp)
echo "All jobs terminated!"
