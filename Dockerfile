# Author:   D. G. Adams
#
# Date:     2026-Nov-06
#
# This project builds and installs piaware, dump1090-fa, and nginx
# into a single "piaware" image. It uses four build layers to keep things clean.

FROM debian:trixie-slim  AS  build1

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
        wget python3-pip python3-build python3-wheel python3-filelock python3-pyasyncore

    git clone "https://github.com/flightaware/piaware_builder.git"
    cd /piaware_builder
    ./sensible-build.sh trixie
    cd ./package-trixie
    dpkg-buildpackage -b --no-sign
EOR
#####################################################################
# The filesystem layer installs piaware and its dependecies into
# a clean version of debian.  This is to remove build artifacts.
# Once installed some file permissions and maintence is done to
# connect piaware and dump1090-fa

FROM debian:trixie-slim AS build2

WORKDIR /dump1090
COPY --from=build1 /piaware_builder/piaware_*_amd64.deb /dump1090/piaware.deb
COPY --from=build1 /dump1090/public_html/ /dump1090/public_html/
COPY --from=build1 /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa /usr/bin

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
# This layer seems to be necessary.  Doesn't work if I combine it with build2.

FROM scratch AS muntz

COPY --from=build2 / /      
COPY files/* /dump1090/     

RUN <<EOR
#!/bin/bash

shopt -s extglob        # bash extension to allow rm -rf !(except_file|...)
set -e

#   remove all library directories except ...
cd /usr/lib
    EXCEPT="!(Tcl*|fa_*|libtclx*"
    EXCEPT+="|os-release|piaware|piaware_packages"
    EXCEPT+="|ssl|tcl*|x86_64*"
    EXCEPT+=")"
rm -rf $EXCEPT

#   remove all libraries except ...
cd /usr/lib/x86_64-linux-gnu
    EXC="!(libc.*|ld-linux*|libresolv.*|libpython*"
    EXC+="|libtcl8.6.*|libz.*|libm.*|libcap*|libpcre2*"
    EXC+="|libcrypt.*|libcrypto.*|librtlsdr.*|libusb*|libudev*"
    EXC+="|libzstd.*|libselinux.*"
    EXC+="|libncurses.*|libpthread.*|libssl.*|libitcl*|libexpat.*|libtinfo*)"
rm -fr $EXC

# clean up tcltk keeping only needed items.  AI claude helped here
cd /usr/share/tcltk/tcllib2.0
    EXC="!(json|pkgIndex.tcl|piaware"
    EXC+="|Itcl|Tclx|cmdline|tls|tryfinallyshim"
    EXC+="|fa_adept_client|fa_gps|fa_piaware_config|fa_services|fa_sudo)"
rm -rf $EXC

cd /usr/share/tcltk/tcl8.6
rm -rf msgs tzdata
cd /usr/share/tcltk/tcl8.6/encoding
rm -f !(ascii.enc|iso8859-1.enc|cp1252.enc)

# Selectively removing stuff
rm -rf /usr/libexec /usr/local /usr/include /usr/src /usr/games
rm -rf /var/lib/dpkg /var/lib/apt                       # CHANGED: also covers dpkg/info and apt/lists
rm -rf /root /home /srv /opt /mnt /media
cd /var/cache   && rm -rf !(piaware)                    # CHANGED: keep /var/cache/piaware
cd /etc         && rm -rf !(passwd|group|gshadow|shadow|piaware*|hosts|resolv.conf)
cd /usr/share   && rm -rf !(ca*|locale|nginx|piaware|tcltk)
cd /usr/sbin    && rm -rf !(nginx)
cd /usr/bin     && rm -rf !(bash|busybox|dump1090-fa|netstat|piaware|pirehose|tcl*|python*)

/bin/busybox --install -s

# check libraries
# CHANGED: also checks every shared object under /usr/lib (Tcl and Python extensions)
for f in /usr/lib/piaware/helpers/* /usr/bin/dump1090-fa /usr/sbin/nginx /usr/bin/netstat \
         $(find /usr/lib -type f -name '*.so*'); do
    if /lib64/ld-linux-x86-64.so.2 --list "$f" 2>/dev/null | grep -q "not found"; then
        echo "MISSING LIBS for $f:"; /lib64/ld-linux-x86-64.so.2 --list "$f" | grep "not found"; exit 1
    fi
done

# finally remove bash and done.
rm -f /bin/bash
EOR
######################################################################
# installation layer
# Making this layer removes all the deleted file space left after muntzing.

FROM scratch AS dga-install
COPY --from=muntz / /
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]
