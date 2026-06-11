FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential flex bison gawk gettext git \
    libncurses-dev libssl-dev \
    python2 python3 python3-setuptools python-is-python3 \
    rsync unzip zlib1g-dev file wget curl ca-certificates patch \
    pkgconf cmake ninja-build cpio perl tar xz-utils \
    gperf help2man autoconf automake libtool bash sudo \
    libelf-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} builder && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash builder

WORKDIR /work
USER builder