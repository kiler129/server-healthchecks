# syntax=docker/dockerfile:1.4

FROM alpine:3

WORKDIR /app
ENV UPDATE_ON_START=0

RUN apk add --no-cache \
    curl bash sed uuidgen procps tini

COPY --link docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

RUN curl -o /app/http-ping.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-ping.sh'
RUN curl -o /app/with-healthcheck.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/with-healthcheck.sh'
RUN curl -o /app/http-middleware.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-middleware.sh'
RUN chmod +x /app/*.sh

ENTRYPOINT ["/sbin/tini", "-v", "--", "docker-entrypoint"]
CMD ["bash", "/app/http-middleware.sh"]
