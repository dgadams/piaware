# Author:   D. G. Adams
#
# Date:     2025-March-16
#
# This project builds and installs piaware, dump1090-fa, and nginx
# into a single "piaware" image. It uses four build layers to keep things clean.

FROM debian:bookworm-slim  AS  dga-build

# Build Dump1090
RUN <<EOR
    apt-get update
    apt-get -yq install build-essential debhelper fakeroot git libncurses-dev \
        librtlsdr-dev pkg-config
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
#####################################################################
# The filesystem layer installs piaware and its dependecies into
# a clean version of debian.  This is to remove build artifacts.
# Once installed some file permissions and maintence is done to
# connect piaware and dump1090-fa

FROM debian:bookworm-slim AS dga-filesystem

WORKDIR /dump1090
COPY --from=dga-build /piaware_builder/piaware_*_amd64.deb /dump1090/piaware.deb
COPY --from=dga-build /dump1090/public_html/ /dump1090/public_html/
COPY --from=dga-build /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa /usr/bin

RUN <<EOR
#   Install piaware and its dependancies
    apt-get -yq update
    apt-get -yq install /dump1090/piaware.deb
    apt-get -yq install nginx libusb-1.0-0 librtlsdr0 libncurses6 busybox
    apt-get clean
    rm -rf /dump1090/piaware.deb /etc/nginx

#   basic piaware and dump1090-fa maintenance
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
EOR
##############################################
# This the muntzing layer.  Uneeded files are removed.
# Muntzing is an iterative process of remove until it breaks and then put it back.
# This layer seems to be necessary.  Doesn't work if I combine it with dga-filesystem.

FROM scratch AS muntz-layer

COPY --from=dga-filesystem / /
COPY files/* /dump1090/

RUN <<EOR
    ./dump1090/muntz.sh
    /bin/busybox --install -s
    rm -f /dump1090/muntz.sh
EOR
######################################################################
# installation layer
# Making this layer removes all the deleted file space left after muntzing.

FROM scratch AS dga-install
COPY --from=muntz-layer / /
EXPOSE 8080
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]