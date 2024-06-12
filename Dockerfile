# syntax=docker/dockerfile:1.8

ARG NODE_VERSION
ARG PYTHON_VERSION=3.11

FROM bitnami/minideb:bookworm as node_build_base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG NODE_VERSION

RUN install_packages xz-utils
COPY --link prebuildfs/ /
RUN mkdir -p /opt/blacksmith-sandbox
RUN mkdir -p /opt/bitnami/node

FROM public.ecr.aws/bitcompat/python:${PYTHON_VERSION} as python

FROM node_build_base as node_build_amd64
ADD --link https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz /opt/blacksmith-sandbox/node.tar.xz

FROM node_build_base as node_build_arm64
ADD --link https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-arm64.tar.xz /opt/blacksmith-sandbox/node.tar.xz

FROM node_build_$TARGETARCH as node_build

WORKDIR /opt/blacksmith-sandbox
RUN <<EOT bash
    set -e
    tar -xJvf node.tar.xz --strip-components=1 -C /opt/bitnami/node
EOT

COPY --from=python /opt/bitnami/python /opt/bitnami/python

ENV PATH="/opt/bitnami/node/bin:$PATH"

ARG NODE_VERSION
RUN mkdir -p /opt/bitnami/node/licenses && mv /opt/bitnami/node/LICENSE /opt/bitnami/node/licenses/node-$NODE_VERSION.txt
RUN node --version # Test run executable

ARG DIRS_TO_TRIM="/opt/bitnami/node/share/man \
/opt/bitnami/node/share/doc \
"

RUN <<EOT bash
    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done

    find /opt/bitnami/node/lib/node_modules/ -name docs -type d -print0 | xargs -0 rm -v -r
    find /opt/bitnami/node/lib/node_modules/ -name man -type d -print0 | xargs -0 rm -v -r
EOT

FROM bitnami/minideb:bookworm as stage-0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DIRS_TO_TRIM="/usr/share/man \
    /var/cache/apt \
    /usr/share/locale \
    /var/log \
    /usr/share/info \
    /tmp \
"

COPY --from=node_build /opt/bitnami /opt/bitnami

ARG NODE_VERSION
ARG TARGETARCH
ENV APP_VERSION=$NODE_VERSION \
    BITNAMI_APP_NAME=node \
    BITNAMI_IMAGE_VERSION="${NODE_VERSION}-prod-debian-12" \
    PATH="/opt/bitnami/node/bin:/opt/bitnami/python/bin:$PATH" \
    LD_LIBRARY_PATH=/opt/bitnami/python/lib/ \
    OS_ARCH=$TARGETARCH \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux"

RUN <<EOT bash
    set -e
    install_packages build-essential ca-certificates curl git libbz2-1.0 libcom-err2 libcrypt1 libffi8 libgcc-s1 libgssapi-krb5-2 libk5crypto3 \
        libkeyutils1 libkrb5-3 libkrb5support0 liblzma5 libncursesw6 libnsl2 libreadline8 libsqlite3-0 libsqlite3-dev libssl-dev \
        libstdc++6 libtinfo6 libtirpc3 pkg-config procps unzip wget zlib1g

    npm i -g node-gyp yarn
    rm -rf /root/.npm

    for DIR in $DIRS_TO_TRIM; do
      find \$DIR/ -delete -print
    done
    rm /var/cache/ldconfig/aux-cache

    find /opt/bitnami/node/lib/node_modules/ -name docs -type d -print0 | xargs -0 rm -v -r

    mkdir -p /app
    mkdir -p /var/log/apt
    mkdir -p /tmp
    mkdir -p /.npm
    chmod 1777 /tmp
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS    90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS    0/' /etc/login.defs
    sed -i 's/sha512/sha512 minlen=8/' /etc/pam.d/common-password
    find /usr/share/doc -mindepth 2 -not -name copyright -not -type d -delete
    find /usr/share/doc -mindepth 1 -type d -empty -delete
EOT

EXPOSE 3000
WORKDIR /app

CMD [ "node" ]

