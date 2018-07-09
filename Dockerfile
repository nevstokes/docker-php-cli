FROM alpine:3.7 AS build

COPY --from=nevstokes/php-src:7.2 php.tar.xz .

ENV PHP_INI_DIR=/usr/local/etc/php

RUN echo '@community http://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories \
    && apk --update-cache upgrade && apk add \
        build-base \
        upx@community \
        xz \
    \
    && mkdir -p /usr/src/php \
    && tar -Jxf php.tar.xz -C /usr/src/php --strip-components=1

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent
# Enable optimization (-Os — Optimize for size)
# Enable linker optimization
# Adds GNU HASH segments to generated executables
# https://github.com/docker-library/php/issues/272

RUN export CFLAGS="-fstack-protector-strong -fpic -fpie -Os" \
    CPPFLAGS="-fstack-protector-strong -fpic -fpie -Os" \
    LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
    \
    && cd /usr/src/php \
    \
    && ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        \
        --disable-all \
        --disable-cgi \
        --disable-phpdbg \
    \
    && make -j "$(getconf _NPROCESSORS_ONLN)" \
    && make install \
    && make clean \
    && { find /usr/local/bin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
    \
    && upx -9 /usr/local/bin/php


FROM nevstokes/busybox

ARG BUILD_DATE
ARG VCS_REF
ARG VCS_URL

ENV PHP_INI_DIR=/usr/local/etc/php

# We'll need the php binary...
COPY --from=libs /usr/local/bin/php /bin/

# ...as well as required shared libraries
COPY --from=libs /lib/ld-musl-x86_64.so.1 /lib/

ENTRYPOINT ["php"]
CMD ["-v"]

LABEL maintainer="Nev Stokes <mail@nevstokes.com>" \
      description="Minimum PHP" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.schema-version="1.0" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url=$VCS_URL
