# Author:   D. G. Adams
#
# Date:     2024-Aug-21
#
# Builds dump1090 with nginx as web server in builder
# Then installs dump1090 and piaware in installer
#
FROM debian:bookworm-slim  as builder

RUN apt-get update && \
    apt-get install -y \
      build-essential \
      debhelper \
      fakeroot \
      git \
      libncurses-dev \
      librtlsdr-dev \
      pkg-config

RUN git clone https://github.com/flightaware/dump1090.git /dump1090
WORKDIR /dump1090
RUN dpkg-buildpackage -b --no-sign --build-profiles=custom,rtlsdr 
#####################################################################

FROM --platform=linux/amd64 debian:bookworm-slim AS installer

COPY --from=builder /dump1090/dump1090 /usr/bin/dump1090
COPY --from=builder /dump1090/public_html/ /dump1090/public_html/
COPY ./packages/piaware_9.0.1_amd64.deb piaware.deb

RUN \
    apt-get update && \
    apt-get install -y \
        nginx \
        libncurses6 \
        librtlsdr0 \
        ./piaware.deb && \
    apt-get clean && \
    mkdir /run/dump1090 && \
    chown piaware /run/dump1090 && \
    chmod 755 /run/dump1090 && \
    chown piaware /etc/piaware.conf && \
    rm ./piaware.deb && \
    rm -rf /etc/nginx && \
    rm -rf /var/lib/apt/lists/*

COPY files/* /dump1090/

EXPOSE 8080 8443
CMD ["/dump1090/piaware-start"]
