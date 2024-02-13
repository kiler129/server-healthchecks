#!/usr/bin/env bash
# HealthCheck script wrapper (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset
cd "$(dirname "$0")"

# Defaults for options with values
maxTime=10 # see option -m help
maxRetry=5 # see option -r help

# Script options
version="2024021301"
updateUrl="https://raw.githubusercontent.com/kiler129/server-healthchecks/main/with-healthcheck.sh"
homeUrl="https://github.com/kiler129/server-healthchecks"

# ===============================================================
# Shows current version of this script
# Params: <none>
# Prints: one-line version-unique string
# Return: <none>
showVersion () {
    echo "HealthChecks script wrapper v$version" 1>&2
}

# Displays script usage
# Params: <none>
# Prints: usage text
# Return: <none>
showUsage () {
    local _baseScript=$(basename $0)
    showVersion
    echo "Usage: $_baseScript [OPTION]... <PING URL> <COMMAND> [OPT]..." 1>&2
    echo 1>&2
    echo "Ping options:" 1>&2
    echo "  -T        Don't track run time (by default it sends ping for start & end)" 1>&2
    echo "  -D        Don't include executed command output in ping" 1>&2
    echo "  -m $maxTime     Maximum amount of time (s) to wait fo ping to succeed" 1>&2
    echo "  -r $maxRetry      How many times (up to -m) ping should repeat" 1>&2
    echo "  -i        Send RunID (rid) in ping. Check HealthChecks docs for details." 1>&2
    echo "            (generated automatically; needs either /proc access or uuidgen binary)" 1>&2
    echo "  -s        Silence failures/report success only. When specified it will behave like it" 1>&2
    echo "            the check was never called, if the external command fails. This is useful" 1>&2
    echo "            for handling intermittently-failing tasks that are expected to do so." 1>&2
    echo "            Unless combined with -X, the exit code will reflect the job's status." 1>&2
    echo 1>&2
    echo "Exec options:" 1>&2
    echo "  -p        Print executed command output (by default it will be silenced)" 1>&2
    echo "  -E        Ignore ping failure in determining this script exits code. I.e. exit" 1>&2
    echo "            with 0 exit code even if ping fails (the command will be run" 1>&2
    echo "            regardless of ping failure and it can fail, see -X)" 1>&2
    echo "  -X        Ignore command failure in determining this script exits code. I.e. exit" 1>&2
    echo "            with 0 exit code even if command fails. Also see -E." 1>&2
    echo "  -n[=code] Dry run - don't run the command but just deliver the ping" 1>&2
    echo "            (you can use this to test parameters & this script, or use this" 1>&2
    echo "            script as a standalone ping script as the command is not checked)." 1>&2
    echo "            Optionally, you can specify simulated exits code (default is 0/success)." 1>&2
    echo 1>&2
    echo "This script options:" 1>&2
    echo "  -v        Print script verbose logs. Normally the script is silent by itself" 1>&2
    echo "  -h        Display this help and exits, ignoring other options" 1>&2
    echo 1>&2
    echo "Special:" 1>&2
    echo "  -u        Self-update this script. Implies -v. This option must be used alone." 1>&2
    echo "            It will also leave a non-executable file \"${_baseScript}_previous\"" 1>&2
    echo "            after update, in case you made some changes and accidentally ran -u." 1>&2
    echo "  --version Prints version of this script and exits. It needs to be the first" 1>&2
    echo "            option. All other options will be ignored."  1>&2
    echo "  --help    Standard alias to -h. It needs to be the first option" 1>&2
    echo 1>&2
    echo "Examples: " 1>&2
    echo "  $_baseScript https://example.com/ping/uuid /scripts/backup.sh -a" 1>&2
    echo "   => Run backup.sh passing argument -a, with pings for start & stop, and include output in ping." 1>&2
    echo 1>&2
    echo "  $_baseScript -T -D https://example.com/ping/uuid /scripts/backup.sh -a" 1>&2
    echo "   => Run backup.sh passing argument -a, WITHOUT 1pings for start (-T) & stop, and DO NOT include output (-D) in ping." 1>&2
    echo 1>&2    
    echo " $_baseScript -e -m 30 https://example.com/ping/uuid whatever" 1>&2
    echo "   => Send ping only taking no longer than 30s, exit with non-zero code if it fails" 1>&2
    echo 1>&2
    echo "Found a bug? Have a question? Head out to $homeUrl"
}

# Displays error message & script usage help, then exits with error
# Params: messageToDisplay
# Prints: error message & help
# Return: always 1
showUsageError () {
    echo -e "Error: $@\n---\n" 1>&2
    showUsage "$0"
    exit 1
}

# Logs verbose/internal message if requested
# WARNING: this function depends on a global variable "verboseMode"
# Params: messageToDisplay
# Prints: messageToDisplay to stderr
# Return: <none>
vLog () {
    if [[ $verboseMode -ne 1 ]]; then return; fi
    echo "=> $@"
}

# Generates UUIDv4
# Params: <none>
# Prints: uuid
# Return: 1 if UUID cannot be generated; 0 otherwise
generateUuid () {
    if [[ -f "/proc/sys/kernel/random/uuid" ]]; then # kernel generates UUIDv4 even on minimal dockers
        cat /proc/sys/kernel/random/uuid
        return
    fi
    if command -v uuidgen &> /dev/null; then
        uuidgen -r
        return
    fi
    showUsageError "Requested UUID to be generated, but neither /proc filesystem nor uuidgen binary are avaialble"
}

# Visits http(s) URL for ping via POST
# WARNING: this function depends on global variables:
# - pingUrl
# - maxTime
# - maxRetry
# - rid
# Params:
# - action: empty string, "start", "fail", or exit code
# - payload: optional; even if not specified the pingUrl will be called with POST for consistency
callPing () {
    local _action="$1"
    local _payload="${2-}"
    local _url="$pingUrl"
    if [[ ! -z "$_action" ]]; then
        _url="$_url/$_action"
    fi
    if [[ ! -z "$rid" ]]; then
        _url="$_url?rid=$rid"
    fi

    local _retCode=0
    local _retOut=""
    if [[ -z "$_payload" ]]; then
       vLog "Calling URL w/o payload: $_url"
       _retOut=$(curl -fsS -m $maxTime --retry $maxRetry -X POST "$_url" 2>&1) || _retCode=$?
    else
       vLog "Calling URL w/payload: $_url"
       _retOut=$(curl -fsS -m $maxTime --retry $maxRetry --data-raw "$_payload" "$_url" 2>&1) || _retCode=$?
    fi
    vLog "Ping output: $_retOut"
    vLog "cURL exit: $_retCode"

    return $_retCode
}

# Updates this script from the update URL
# WARNING: this function depends on global variable "updateUrl"
# Params: <none>
# Prints: logs
# Return: direct exit 0 on success, or 1 on failure
selfUpdate () {
    local _baseScript=$(basename $0)
    showVersion
    vLog "Updating $_baseScript from $updateUrl"
    if [[ ! -w "$_baseScript" ]]; then
        vLog "Script file is not writeable!"
        exit 1
    fi

    curVersion=$(cat "$_baseScript")
    vLog "Downloading latest version..."
    newVersion=$(curl -fS "$updateUrl")
    if [[ "$curVersion" == "$newVersion" ]]; then
        vLog "Current version is already up to date - nothing to do"
        exit 0
    fi

    local _previous="${_baseScript}_previous"
    vLog "New version detected - backing up & updating"
    cp "$_baseScript" "$_previous"
    chmod -x "$_previous"
    set +o noclobber
    echo "$newVersion" >| "$_baseScript"
    chmod +x "$_baseScript"

    vLog "Update succesful. New version installed:"
    "./$_baseScript" --version
    exit 0
}

# ===============================================================
#### Parse all options
sendStart=1
includeOutput=1
silenceCmd=1
passPingExit=1
passCmdExit=1
rid=""
pingOnFailures=1
dryRun=-1
verboseMode=0

# I'm avoid using getopt which is not available on some platforms
# This will work as long as this is a first option, so it's not
# really docummented, but people commonly use that
argsNum=$#
if [[ $argsNum -ge 1 ]]; then
    if [[ "$1" == "--help" ]]; then showUsage; exit 0; fi
    if [[ "$1" == "--version" ]]; then showVersion; exit 0; fi
fi

while getopts ':TDpEXm:r:isnvuh' opt; do
    case "$opt" in
        T) sendStart=0 ;;
        D) includeOutput=0 ;;
        p) silenceCmd=0 ;;
        E) passPingExit=0 ;;
        X) passCmdExit=0 ;;
        m) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for ping timeout (-m): \"$OPTARG\" is not an number"
           fi
           maxTime=$OPTARG ;;
        r) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for max retries (-r): \"$OPTARG\" is not a number"
           fi
           maxRetry=$OPTARG ;;
        i) rid=$(generateUuid) ;;
        s) pingOnFailures=0 ;;
        n) # this uses a hack from https://stackoverflow.com/a/38697692 as getopts doesn't support optional arguments
           # also, in case this option was used as last one we don't want to sweep the first argument (URL in this case)
           #   as a value when -n is the last option, i.e. if it's not an integer we assume it's a non-value call
           # we're deliberately catching negative numbers to provide better user experience
           peekNextOpt=${!OPTIND}
           if [[ -n "${peekNextOpt}" ]] && [[ "${peekNextOpt}" =~ ^-?[0-9]+$ ]]; then
               OPTIND=$((OPTIND + 1))
               dryRun=$peekNextOpt
           else
               dryRun=0
           fi

           if [[ $dryRun -lt 0 ]] || [[ $dryRun -gt 255 ]]; then
               showUsageError "Dry run (-n) value, if passed, must be a valid exit code (integer 0-255), but got \"${dryRun}\""
           fi ;;
        v) verboseMode=1 ;;
        u) if [[ $argsNum -gt 1 ]]; then
               # this is a safety measure to prevent accidental invocations with -u somewhere
               showUsageError "Self-update (-u) must NOT be called with any other arguments"
           fi
           verboseMode=1
           selfUpdate ;;
        h) showUsage
           exit 0 ;;
        ?) showUsageError "Invalid command option \"-${OPTARG}\" specified" ;;
    esac
done
shift "$(($OPTIND -1))"
if [[ $# -lt 2 ]]; then
    showUsageError "Ping URL and command to execute are mandatory"
fi

# Normally ping should never fail the actual job, but this is a misconfiguration of
# this script directly. In other words, an admin will (hopefully) run it at least
# once before deploying it to cron
pingUrl="${1%/}"; shift
cmdToExec="$1"; shift
if [[ "$pingUrl" != http* ]]; then
    showUsageError "Ping URL \"$pingUrl\" is invalid: it does not start with http"
fi
if [[ "$pingUrl" =~ /(start|fail|[0-9]+)/?$ ]]; then
    showUsageError "Ping URL \"$pingUrl\" is invalid: it should not contain an action (e.g. /start) nor exit code (/<number>)"
fi
if [[ "$pingUrl" == *"?"* ]]; then
    showUsageError "Ping URL \"$pingUrl\" is invalid: it should not contain query string (did you try to use ?rid= instead of -i?)"
fi

# ===============================================================
# Ping & execution logic
scriptExitCode=0 # exit code for this script (reportExitCode set later is sent to ping)
pingExitCode=0
if [[ $sendStart -eq 1 ]]; then
    vLog "Reporting job start"
    callPing start || pingExitCode=$?
    if [[ $passPingExit -eq 1 ]] && [[ $pingExitCode -gt 0 ]]; then scriptExitCode=$pingExitCode; fi
    vLog "Computed exit: $scriptExitCode"
else
    vLog "Skipped job start report"
fi

# If tee is available and -s wasn't specified we can stream the output; otherwise it
# delivered after the command finishes if desired
cmdExitCode=0
cmdOut=""
if [[ $dryRun -eq -1 ]]; then # "-1" indicates disabled; any other value is a desired exit code
    vLog "Running command: $cmdToExec $@"
    if ! command -v tee &> /dev/null || [[ $silenceCmd -eq 1 ]]; then
        vLog "Output streaming disabled (silence=$silenceCmd == 1 or tee unavailable)"
        cmdExitCode=0
        cmdOut=$("$cmdToExec" "$@" 2>&1) || cmdExitCode=$?
        if [[ $silenceCmd -ne 1 ]] && [[ ! -z "$cmdOut" ]]; then echo "$cmdOut"; fi
    else
        vLog "Output streaming enabled"
        exec 5>&1
        cmdExitCode=0
        cmdOut=$("$cmdToExec" "$@" 2>&1 | tee >(cat - >&5)) || cmdExitCode=$?
        silenceCmd=1 # output was already streamed
    fi
else
    vLog "Skipped command exec (dry mode), simulating exit=$dryRun"
    cmdExitCode=$dryRun
fi
vLog "Command exec done w/exit: $cmdExitCode"

# cmd failure overrides ping exit code, but cmd success shouldn't override ping fail
if [[ $passCmdExit -eq 1 ]] && [[ $cmdExitCode -gt 0 ]]; then scriptExitCode=$cmdExitCode; fi

# command status is usually reported regardless whether it failed or not
# however, when failures are supposed to be silenced we shouldn't ping if command failed (but still ping for OK)
if [[ $cmdExitCode -eq 0 ]] || [[ $pingOnFailures -eq 1 ]]; then
  vLog "Reporting job end w/code: $cmdExitCode"
  if [[ $includeOutput -eq 1 ]]; then
    callPing "$cmdExitCode" "$cmdOut" || pingExitCode=$?
  else
    callPing "$cmdExitCode" "" || pingExitCode=$?
  fi
else
  vLog "The command failed w/code: $cmdExitCode. The report will be suppressed (-s option passed)"
fi

if [[ $passPingExit -eq 1 ]] && [[ $pingExitCode -gt 0 ]] && [[ $scriptExitCode -eq 0 ]]; then
    scriptExitCode=$pingExitCode
fi
vLog "Computed exit: $scriptExitCode"

exit $scriptExitCode
