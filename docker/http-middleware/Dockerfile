# syntax=docker/dockerfile:1.4

FROM alpine:3
WORKDIR /app

RUN apk add --no-cache \
    curl bash sed uuidgen

RUN curl -o /app/http-ping.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-ping.sh'
RUN curl -o /app/with-healthcheck.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/with-healthcheck.sh'
RUN curl -o /app/http-middleware.sh 'https://raw.githubusercontent.com/kiler129/server-healthchecks/main/http-middleware.sh'
RUN chmod +x /app/*.sh

CMD ["bash", "/app/http-middleware.sh"]
