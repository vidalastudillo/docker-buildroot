FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    build-essential \
    bash \
    bc \
    binutils \
    bzip2 \
    cpio \
    file \
    g++ \
    gcc \
    git \
    gzip \
    locales \
    libncurses5-dev \
    libdevmapper-dev \
    libsystemd-dev \
    make \
    mercurial \
    whois \
    patch \
    perl \
    python3 \
    rsync \
    sed \
    tar \
    vim \ 
    unzip \
    wget \
    bison \
    flex \
    libssl-dev \
    libfdt-dev \
    nano \
    graphviz \
    python3-pip \
    pipx \
    python3-six \
    python3-dotenv
    
# `six` and `spdx_lookup` packages are required to run `utils/scanpypi` which 
# fetchs python-packages from the PyPI repository: https://pypi.python.org/
# and to improve its licenses detection.

# `dotenv` is used by Python scripts developed by V&A that use Environment
# variables to build the images.

RUN pipx install spdx_lookup

# Sometimes Buildroot need proper locale, e.g. when using a toolchain
# based on glibc.
RUN locale-gen en_US.utf8

# This will be a folder used to link content from the host related to
# Buildroot's external mechanism
RUN mkdir -p /buildroot_externals

WORKDIR /root/buildroot

# The following is set after upgrading from ubuntu:20.04 to ubuntu:24.04
# Otherwise the build process complains about running as a root.
# More info at: https://stackoverflow.com/questions/69026206/running-buildroot-as-root-still-error-after-setting-force-unsafe-configure-1-in
ENV FORCE_UNSAFE_CONFIGURE=1

RUN ["/bin/bash"]
