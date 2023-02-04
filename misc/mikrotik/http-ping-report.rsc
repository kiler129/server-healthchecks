# This is a quick RouterOS v7+ script to check external
# URL and report status of it via ping.
#
# This is useful for e.g. pinging SwOS devices from
# the edge router. You should add it to /system/scheduler
# with permissions of at least "read" and "test".

# Configuration
:global checkUrl "http://10.0.0.15"
:global pingUrl "hhttps://example.com/ping/ffffffff-eeee-aaaa-bbbb-123456789abc"
:global checkUrlVerifySsl "no"

################## DO NOT CHANGE BELOW ##################
do {
  /tool/fetch keep-result=no duration=2s \
              check-certificate=$checkUrlVerifySsl \
              "$checkUrl"
  do {
    /tool/fetch keep-result=no http-method=post "$pingUrl"
  } on-error={
    :log error "Failed to ping $pingUrl"
  }
} on-error={
  do {
    /tool/fetch keep-result=no "$pingUrl/fail"
  } on-error={
    :log error "Failed to report $checkUrl failure to $pingUrl"
  }
}
