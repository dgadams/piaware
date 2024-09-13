# Author:   D. G. Adams
#
# Date:     2024-Aug-21
#
# Builds dump1090 with nginx as web server in builder
# Then installs dump1090 and piaware in installer
#
FROM debian:bookworm-slim  AS  builder

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

#####################################################################

FROM debian:bookworm-slim AS installer

COPY --from=builder /dump1090/dump1090 /usr/bin/dump1090
COPY --from=builder /dump1090/public_html/ /dump1090/public_html/
COPY ./packages/piaware_9.0.1_amd64.deb piaware.deb

RUN <<EOF
#   Load dependencies and piaware
    apt-get update 
    apt-get -yq install \
        nginx \
        libncurses6 \
        librtlsdr0 \
        ./piaware.deb 

#   Clean up after apt-get
    apt-get clean 
    rm -rf /var/lib/apt/lists/* 
    rm ./piaware.deb 
#
#   setup and change ownership of directories
    mkdir /run/dump1090
    mkdir /run/piaware
    touch /run/piaware/status.json
    touch /dump1090/public_html/upintheair.json
    chown -R piaware /run/dump1090
    chown -R piaware /run/piaware
    chown -R piaware /var/log/nginx
    chown -R piaware /var/lib/nginx
    chmod -R 755 /run/dump1090
    chown piaware /etc/piaware.conf
    rm -rf /etc/nginx
#
#   Remove some debian files not needed
    rm -rf /usr/share/doc
    rm -rf /usr/share/zoneinfo
EOF

COPY files/* /dump1090/
EXPOSE 8080
USER piaware
CMD ["/dump1090/piaware.sh"]
