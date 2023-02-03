# syntax=docker/dockerfile:1.4

FROM alpine:3

WORKDIR /app
ENV UPDATE_ON_START=0

RUN apk add --no-cache \
    curl bash sed uuidgen procps tini

COPY --link docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN chmod +x /usr/local/bin/docker-entrypoint && \
    curl -o /app/http-ping 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-ping.sh' && \
    curl -o /app/with-healthcheck 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/with-healthcheck.sh' && \
    curl -o /app/http-middleware 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-middleware.sh' && \
    chmod +x /app/*

ENTRYPOINT ["/sbin/tini", "--", "docker-entrypoint"]
CMD ["/app/http-middleware"]
