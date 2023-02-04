# Server Healthchecks

This is a repository housing various scripts useful for monitoring and reporting server's health status. They're geared 
to be used with the [Healthchecks](https://github.com/healthchecks/healthchecks) monitoring software, either self-hosted
or [cloud-hosted Healthchecks.io](https://healthchecks.io). However, most scripts can be used independently with small
modifications or as-is.

## Contents of this repo
All scripts are documented (run with `-h`) and require mostly just Bash & curl. This list serves as just a general 
overview.

- The main directory contains healthcheck-specific scripts
- `misc` contains useful status-gathering scripts for different platforms
- `docker` contains premade recipes & docs for running this in dockr

---

### [`with-healthcheck`](with-healthcheck.sh) - automatically report status of any command
A flexible wrapper script which can report status of any commands you execute, report their execution time, and more.

The Healthcheck's [official documentation](https://healthchecks.io/docs/bash/) is a good start. However, it assumes that
you can and will modify all your scripts with `curl` calls. This is sometimes quite hard, or requires individual 
wrappers for each script. Instead, going with a Unix philosophy, the `with-healthchecks.sh` will take care of all 
real-world complexity of implementing health check calls. 

To use it, instead of calling your script `/root/foo/script.sh` use `with-healthchecks http://hc_url/ping/123 /root/foo/script.sh`.

Crontab example:
```diff
# m h  dom mon dow   command
-0 2 1 * * /sbin/zpool scrub -w tank
+0 2 1 * * /root/scripts/with-healthcheck https://example.com/ping/123 /sbin/zpool scrub -w tank
```

**Features overview:**
 - Reporting success/failure separately ([official docs](https://healthchecks.io/docs/signaling_failures/))
 - Reporting with execution time ([official docs](https://healthchecks.io/docs/measuring_script_run_time/))
 - Auto-reporting RunIDs
 - Include executed command output if desired 
 - Forward or silence executed command output and status to crontab (i.e. no more `1>&2 /dev/null` ;))

---

### [`http-middleware`](http-middleware.sh) - poll & report external services status
Normally Healthchecks is a push-based system, i.e. requires destination systems to report to a HTTP(S) endpoint every
so often. It is not always possible to achieve that for appliances and black-box software. However, most software 
contains some ping/status/identity endpoint you can query to see if a device/system is alive. HTTP Middleware combines
`with-healthcheck` and `http-ping` to implement a pull-based checks:

1. Queries a HTTP(S) endpoint
2. Checks its HTTP status
3. Reports to Healtchecks instance whether it was a success or a failure
4. Repeats the process again in set intervals

With this you can monitor e.g. a Plex Media Server instance (`/identity` endpoint) runnin on a NAS. You can even report 
status of your [self-hosted Healthchecks](https://github.com/healthchecks/healthchecks) installation to Healthchecks.io
via `/api/v2/status/` endpoint :)

The HTTP Middleware is especially useful in containerized environment. It can easily be added as an additional service
in `docker compose` and automatically report status of services to a Healthchecks instance. See the [`docker/`](docker/) 
folder for details.

---

### [`http-ping`](http-ping.sh) - check external service status
Small script which visits a HTTP(S) URL and reports whether it was reachable. The reachability status is reported via
unix exit code. 

While this is an ostensibly simple task, as this script is a wrapper around `curl`. The complexity start
when you need to check for HTTP status codes, as `curl` doesn't have a built-in way to handle this. This script lets you
define list of HTTP codes considered successful. In some instances you may want to consider e.g. [HTTP/401](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401)
a sign of the endpoint being alive:

```
# by default only 200 and 204 are considered successful
% http-ping http://httpstat.us/401 ; echo $?
1

# consider 204 and 401 successful (-c) and print output (-p)
% http-ping -p -c 204,401 http://httpstat.us/401 ; echo $?
401 Unauthorized
0
```
