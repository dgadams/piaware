# Author:   D. G. Adams
#
# Date:     2024-Sep-18
#
# This is the smallest piaware image I can get. Done by muntzing the files
# from the build image.  Now down to 76 MB.
# Piaware appears to use command line commands, thus needs a good debian OS.

FROM debian:bookworm-slim  AS  build

# Build Dump1090
RUN <<EOR
    apt-get update
    apt-get -yq install \
      build-essential \
      debhelper \
      fakeroot \
      git \
      libncurses-dev \
      librtlsdr-dev \
      pkg-config
    git clone https://github.com/flightaware/dump1090.git /dump1090
    cd /dump1090
    dpkg-buildpackage -b --no-sign --build-profiles=custom,rtlsdr
EOR

# Build Piaware
RUN <<EOR
    apt-get -yq install devscripts tcl8.6-dev autoconf \
        python3-dev python3-venv python3-setuptools libz-dev openssl \
        libboost-system-dev libboost-program-options-dev libboost-regex-dev \
        libboost-filesystem-dev patchelf libncurses6 librtlsdr0 net-tools \
        wget python3-pip python3-build python3-wheel
    git clone "https://github.com/flightaware/piaware_builder.git"
    cd /piaware_builder
    ./sensible-build.sh bookworm
    cd ./package-bookworm
    dpkg-buildpackage -b --no-sign
EOR

# Set up files
WORKDIR /base/dump1090
RUN <<EOR
    mv /piaware_builder/piaware_9.0.1_amd64.deb ./piaware.deb
    mv /dump1090/public_html/ .
EOR
WORKDIR /base/usr/bin
RUN mv /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa .
#####################################################################

# This build level creates the file system for the install
# loading packages and piaware.deb
# Then removing unneeded files using muntz.sh

FROM debian:bookworm-slim AS filesystem

COPY --from=build /base /
RUN <<EOR
    apt-get -yq update
    apt-get -yq install /dump1090/piaware.deb
    apt-get -yq install nginx libusb-1.0-0 librtlsdr0 libncurses6
    apt-get -yq install busybox
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -f /dump1090/piaware.deb
EOR

COPY files/* /dump1090
RUN <<EOR
    ./dump1090/muntz.sh
    rm -f /dump1090/muntz.sh
EOR
######################################################################

FROM scratch AS install

#   Get the filesystem.
COPY --from=filesystem / /

RUN <<EOR
    adduser --no-create-home --disabled-login --disabled-password piaware
    mkdir /run/dump1090
    mkdir /var/run/piaware
    mkdir /var/cache/piaware
    touch /etc/piaware.conf
    touch /dump1090/public_html/upintheair.json
    chown -R piaware /run/dump1090
    chown -R piaware /run/piaware
    chown -R piaware /var/cache/piaware
    chown -R piaware /var/log/nginx
    chown -R piaware /var/lib/nginx
    chown piaware /etc/piaware.conf
    chown piaware /dump1090/public_html
    rm -rf /etc/nginx
EOR

EXPOSE 8080
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]
