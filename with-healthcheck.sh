#!/usr/bin/env bash
# HealthCheck script wrapper (c) Gregory Zdanowski-House
# Licensed under GPLv2.0 by https://github.com/kiler129
set -e -o errexit -o pipefail -o noclobber -o nounset
cd "$(dirname "$0")"

# Defaults for options with values
maxTime=10 # see option -m help
maxRetry=5 # see option -r help

# Script options
version="2023020102"
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
    echo "  -t      Track run time (send ping for start & end)" 1>&2
    echo "  -d      Include executed command output in ping" 1>&2
    echo "  -m $maxTime   Maximum amount of time (s) to wait fo ping to succeede" 1>&2
    echo "  -r $maxRetry    How many times (up to -m) ping should repeat" 1>&2
    echo "  -i      Send RunID (rid) in ping. Check HealthChecks docs for details." 1>&2
    echo "          (generated automatically; needs either /proc access or uuidgen binary)" 1>&2
    echo 1>&2
    echo "Exec options:" 1>&2
    echo "  -s      Silence executed command output from being printed" 1>&2
    echo "  -e      Exit with non-0 exit code if ping fails" 1>&2
    echo "          (the command will be run regardless of ping failure)" 1>&2
    echo "  -n      Dry run - don't run the command but just deliver the ping" 1>&2
    echo "          (you can use this to test parameters & this script, or use this" 1>&2
    echo "          script as a standalone ping script as the command is not checked)" 1>&2
    echo 1>&2
    echo "This script options:" 1>&2
    echo "  -v      Print script verbose logs. Normally the script is silent by itself" 1>&2
    echo "  -h      Display this help and exits, ignoring other options" 1>&2
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
    echo "  $_baseScript -t -d https://example.com/ping/uuid /scripts/backup.sh -a" 1>&2
    echo "   => Run backup.sh passing argument -a, with pings for start (-t) & stop, and include output (-d) in ping." 1>&2
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
    echo -e "Error: $1\n---\n" 1>&2
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
    echo "=> $1"
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
        return
    fi

    local _previous="${_baseScript}_previous"
    vLog "New version detected - backing up & updating"
    cp "$_baseScript" "$_previous"
    chmod -x "$_previous"
    echo "$newVersion" >| "$_baseScript"
    chmod +x "$_baseScript"

    vLog "Update succesful. New version installed:"
    "./$_baseScript" --version
    exit 0
}

# ===============================================================
#### Parse all options
sendStart=0
includeOutput=0
silenceCmd=0
passPingExit=0
rid=""
dryRun=0
verboseMode=0

# I'm avoid using getopt which is not available on some platforms
# This will work as long as this is a first option, so it's not
# really docummented, but people commonly use that
argsNum=$#
if [[ $argsNum -ge 1 ]]; then
    if [[ "$1" == "--help" ]]; then showUsage; exit 0; fi
    if [[ "$1" == "--version" ]]; then showVersion; exit 0; fi
fi

while getopts ':tdsem:r:invuh' opt; do
    case "$opt" in
        t) sendStart=1 ;;
        d) includeOutput=1 ;;
        s) silenceCmd=1 ;;
        e) passPingExit=1 ;;
        m) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for ping timeout (-m): \"$OPTARG\" is not an number"
           fi
           maxTime=$OPTARG ;;
        r) if [[ "$OPTARG" =~ [^0-9] ]]; then
               showUsageError "Invalid value for max retries (-r): \"$OPTARG\" is not a number"
           fi
           maxRetry=$OPTARG ;;
        i) rid=$(generateUuid) ;;
        n) dryRun=1 ;;
        v) verboseMode=1 ;;
        u) if [[ $argsNum -gt 1 ]]; then
               # this is a safety measure to prevent accidental invocations with -u somewhere
               showUsageError "Self-update (-u) must NOT be called with any other arguments"
           fi
           verboseMode=1
           selfUpdate ;;
        h) showUsage
           exit 0 ;;
        ?) showUsageError "Invalid command option specified";;
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
# delievered after the command finishes if desired
cmdExitCode=0
cmdOut=""
if [[ $dryRun -ne 1 ]]; then
    vLog "Running command: $cmdToExec $@"
    if ! command -v tee &> /dev/null || [[ $silenceCmd -eq 1 ]] || true; then
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
    vLog "Skipped command exec (dry mode)"
fi
vLog "Command exec done w/exit: $cmdExitCode"

# cmd failure overrides ping exit code, but cmd success shouldn't override ping fail
if [[ $cmdExitCode -gt 0 ]]; then scriptExitCode=$cmdExitCode; fi

vLog "Reporting job end w/code: $cmdExitCode"
callPing "$cmdExitCode" "$cmdOut" || pingExitCode=$?
if [[ $passPingExit -eq 1 ]] && [[ $pingExitCode -gt 0 ]] && [[ $cmdExitCode -eq 0 ]]; then
    scriptExitCode=$pingExitCode
fi
vLog "Computed exit: $scriptExitCode"

exit $scriptExitCode
