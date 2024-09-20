# Author:   D. G. Adams
#
# Date:     2024-Sep-18
#
FROM debian:bookworm-slim  AS  build

# Build Dump1090
RUN <<EOF
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
EOF

# Build Piaware
RUN <<EOF
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
EOF

RUN  apt-get -yq install /piaware_builder/piaware_9.0.1_amd64.deb

# Here we do some reverse Muntzing (Lookup Earl "Madman" Muntz). 
# Just grabbing the minimum set of libraries needed to function

WORKDIR /libs
RUN <<EOR
    mv /lib/piaware .
    mv /lib/piaware_packages .
    mv /lib/pirehose .
    mv /lib/Tcllauncher1.10 .
    mv /lib/tclx8.4 .
    mv /lib/fa_adept_codec .
    mv /lib/tcltk/x86_64-linux-gnu/tcltls1.7.22 .
    mv /usr/share/tcltk/* .
    cp /lib/libtclx8.4.so.0 .
    cp /lib/x86_64-linux-gnu/libncurses.so.6 .
    cp /lib/x86_64-linux-gnu/librtlsdr.so.0 .
    cp /lib/x86_64-linux-gnu/libtinfo.so.6 .
    cp /lib/x86_64-linux-gnu/libselinux.so.1 .
    cp /lib/x86_64-linux-gnu/libpcre2-8.so.0 .
EOR

WORKDIR /pibin
RUN <<EOR
    cp /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa .
    cp /usr/bin/netstat .
    cp /usr/bin/piaware .
    cp /usr/bin/pirehose .
    cp /usr/bin/tcllauncher .
EOR
#####################################################################

FROM bellsoft/alpaquita-linux-base:stream-glibc AS install

WORKDIR /dump1090
COPY --from=build /dump1090/public_html/ /dump1090/public_html/
COPY --from=build /libs /lib
COPY --from=build /pibin /usr/bin/

RUN <<ENDRUN
    apk --no-cache add nginx libusb tcl tk bash
#    apk --no-cache libgcc libstdc++ libssl3 iproute2 libexpat libffi
    adduser -DH piaware

#   setup and change ownership of directories
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
ENDRUN

COPY files/* /dump1090/
EXPOSE 8080
USER piaware
CMD ["/dump1090/piaware.sh"]
