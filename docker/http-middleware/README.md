# Runnig in Docker

Before you start, ask yourself if you *need* a docker image. The middleware and accompanying elements are simply bash
scripts. You can run them on any machine with ease. You can run each of them with `-h` to see the options.  
However, if you need to ping things inside of docker network(s) you need to use the containerized approach.

### Premade images
Docker Hub contains premade image at https://hub.docker.com/r/kiler129/server-healthchecks. They're tagged with a date
of when they were built. The releases there are generally infrequent (at least for now), as images upon running with
`UPDATE_ON_START=1` environment variable set will auto-update all scripts inside to the newest version.

### Using in `docker-compose`
You can use this tool, like any other, in compose. Example below illustrates that:

```yaml
version: '2'
services:
    web1:
        image: strm/helloworld-http
    web2:
        image: strm/helloworld-http
    healthcheck:
        image: kiler129/server-healthchecks:latest
        environment: # see help for details (next section)
            CHECK_URL_1: http://web1
            PING_URL_1: https://example.com/ping/48ba312a-db88-4f76-a694-2c27359d5843
            CHECK_URL_2: http://web2
            PING_URL_2: https://example.com/ping/48ba312a-db88-4f76-a694-2c27359d5843
```

### Executing individual commands
Since the image contains all scripts in `/app` you can call them with a normal `docker run`. Example for getting
help for the middleware:

```
% docker run kiler129/server-healthchecks /app/http-middleware -h
Starting HTTP middleware with /app/http-middleware -h
HTTP Middleware v2023020203
Usage: http-middleware [OPTION]...

//...continued...
```

## Building Images
### Standard images
Images for the Hub are built with `linux/amd64` and `linux/arm64` architectures using the following list of steps:

1. `git clone git@github.com:kiler129/server-healthchecks.git`
2. `cd server-healthchecks/docker/http-middleware`
3. ```
   docker buildx build --no-cache --push \
      --platform linux/amd64,linux/arm64 \
      --tag kiler129/server-healthchecks:<date><version> \
      --tag kiler129/server-healthchecks:latest .
   ```
   Where `<date>` is `YYYMMDD` and `<version>` is a version in a given day (e.g. `01`).

### Git images
By default, the [`Dockerfile`](Dockerfile) downloads the latest version of scripts. If you want experiment locally you
can use [`Dockerfile-git`](Dockerfile-git) which take scripts from current directory instead of downloading them. If
you checked out from git and `cd` into the directory with `Dockerfile-git` you need to specify correct context:

```
docker build --no-cache -t http-middleware-git -f Dockerfile-git ../../
docker run \
    -e MIDDLEWARE_DEBUG=1 \
    -e PING_URL_1=https://example.com/ping/uuid \
    -e CHECK_URL_1=http://example.com/ \
    http-middleware-git
```

**However**, most of the time you can probably just replace scripts with volume bind. You just need to make sure they 
are executable (`chmod +x`) and have no `.sh` suffix. Then you can simply run:

```
docker run \
    -e MIDDLEWARE_DEBUG=1 \
    -e PING_URL_1=https://example.com/ping/uuid \
    -e CHECK_URL_1=http://example.com/ \
    -v $(pwd):/app \
    kiler129/server-healthchecks
```
