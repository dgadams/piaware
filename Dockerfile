# Author:   D. G. Adams
#
# Date:     2025-March-14
#
# This is the smallest piaware image I can get. Done by muntzing the files
# from the build image.  Now down to less than 60 Mbytes.

FROM debian:bookworm-slim  AS  dga-build

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

# The needed files are in
# 1. /piaware_builder/piaware_*_amd64.deb Note: * in filename allows versions to change.
# 2. /dump1090/public_html
# 3. /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa

#####################################################################
# This build level creates the file system for piaware.

FROM debian:bookworm-slim AS dga-filesystem

#	COPY scripts and all needed files from dga-build.
COPY files/* /dump1090/
COPY --from=dga-build /piaware_builder/piaware_*_amd64.deb /dump1090/piaware.deb
COPY --from=dga-build /dump1090/public_html/ /dump1090/public_html/
COPY --from=dga-build /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa /usr/bin

RUN <<EOR
#	Install piaware and load dependancies
    apt-get -yq update
    apt-get -yq install /dump1090/piaware.deb
    apt-get -yq install nginx libusb-1.0-0 librtlsdr0 libncurses6 busybox

#	Make directories and set permissions
    mkdir /run/dump1090
    mkdir /run/dump1090-978
    mkdir /var/run/piaware
    touch /etc/piaware.conf
    touch /dump1090/public_html/upintheair.json
	touch /run/dump1090-978/receiver.json
    chown -R piaware /run/dump1090
    chown -R piaware /run/piaware
    chown -R piaware /var/cache/piaware
    chown -R piaware /var/log/nginx
    chown -R piaware /var/lib/nginx
    chown -R piaware /dump1090/public_html
    chown -R piaware /etc/piaware.conf

# Finally muntz the files.
    ./dump1090/muntz.sh
    /bin/busybox --install -s
	rm -rf /dump1090/muntz.sh /dump1090/piaware.deb /etc/nginx
EOR
######################################################################
# Final installation build level to clean up the image.

FROM scratch AS dga-install
COPY --from=dga-filesystem / /
EXPOSE 8080
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]
