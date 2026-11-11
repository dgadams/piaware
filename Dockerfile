# Author:   D. G. Adams
#
# Date:     2026-Nov-06
#
# This project builds and installs piaware, dump1090-fa, and nginx
# into a single "piaware" image. It uses three stages: build, install, and scratch.

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
# The install stage installs piaware and its dependecies into
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
    echo "{}" > /dump1090/public_html/db/~.json

#   compress files in public_html
    cd /dump1090/public_html
    find . -type f \( -name '*.json' -o -name '*.js' -o -name '*.css' -o -name '*.svg' \) \
         ! -name upintheair.json -exec gzip -9 {} +

    chown -R piaware /run/dump1090
    chown -R piaware /run/piaware
    chown -R piaware /var/cache/piaware
    chown -R piaware /var/log/nginx
    chown -R piaware /var/lib/nginx
    chown piaware /etc/piaware.conf
    chown piaware /dump1090/public_html
EOR

##############################################
# Build the final filesystem in /out by copying IN only what is needed.
# Nothing is deleted, so the muntz stage is no longer needed and
# scratch gets a minimal, clean filesystem.
#
# Steps:  1. copy the files in
#         2. busybox and the loader
#         3. check that /out is self-contained
# cp -a keeps the piaware ownership set above.

ENV OUT=/out

# piaware.sh, nginx.conf, etc.
COPY files/* /out/dump1090/

# Replaces the stock tcllib pkgIndex.tcl, which describes every tcllib module and
# so expects directories we removed. This one loads the index of each module that is there.
# Tcl sources a pkgIndex.tcl with $dir set to its own directory, so $dir is pointed at
# each module while its index loads, then put back.
COPY <<'EOT' /out/usr/share/tcltk/tcllib2.0/pkgIndex.tcl
set tcllib_dir $dir
foreach index [glob -nocomplain -directory $tcllib_dir */pkgIndex.tcl] {
    set dir [file dirname $index]
    source $index
}
set dir $tcllib_dir
EOT

# ---------------------------------------------------------------
# Step 1: directory layout, then copy in everything on the lists below.
# The paths are relative to /, and cp --parents recreates each one under /out.
# A name that does not exist is skipped, and reported in the build log (look for "skipping missing").
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail
    shopt -s nullglob extglob       # nullglob: unmatched globs vanish; extglob: !(a|b)

#   --- layout: same merged-/usr symlinks as Debian ---
    mkdir -p $OUT/lib64 $OUT/var $OUT/tmp
    chmod 1777 $OUT/tmp
    ln -s usr/lib  $OUT/lib
    ln -s usr/bin  $OUT/bin
    ln -s usr/sbin $OUT/sbin
    ln -s ../run   $OUT/var/run

    cd /

    BINS=(
        usr/bin/{busybox,dump1090-fa,netstat,piaware}  usr/bin/tcl*
        usr/sbin/nginx
    )

#   Every library the image needs is named here. Step 3 fails the build if one is missing.
#   ld-linux is left out: step 2 puts it in /lib64.
    M=usr/lib/x86_64-linux-gnu
    LIBS=(
        usr/lib/{Tcl*,fa_*,libtclx*,os-release,piaware,piaware_packages,ssl,tcl*}
        $M/{libc.*,libm.*,libresolv.*,libpthread.*,libcrypt.*}    # C library
        $M/{libz.*,libzstd.*,libpcre2*,libexpat.*}                # compression, regex, xml
        $M/{libssl.*,libcrypto.*}                                 # TLS
        $M/{libcap*,libselinux.*,libncurses.*,libtinfo*}          # nginx, netstat
        $M/{libusb*,libudev*,librtlsdr.*}                         # dongle access
        $M/{libpython*,libtcl8.6.*,libitcl*}                      # mlat and tcl
    )

#   tcltk: everything except tcllib2.0 and tcl8.6, which are trimmed.
#   tcllib2.0/pkgIndex.tcl comes from the COPY above.
    TCL=(
        usr/share/tcltk/!(tcllib2.0|tcl8.6)
        usr/share/tcltk/tcllib2.0/{json,aes,cmdline,0compatibility}
        usr/share/tcltk/tcl8.6/!(msgs|tzdata|encoding)
        usr/share/tcltk/tcl8.6/encoding/{ascii,iso8859-1,cp1252}.enc
    )

#   data, and the directories piaware and nginx write to
    DATA=(
        usr/share/{nginx,piaware}
        etc/{passwd,group}  etc/piaware*
        var/cache/piaware  var/log/nginx  var/lib/nginx
        run/dump1090  run/piaware
        dump1090/public_html
    )

#   keep only the names that exist, and say which ones were skipped
    KEEP=()
    for p in "${BINS[@]}" "${LIBS[@]}" "${TCL[@]}" "${DATA[@]}"; do
        if [ -e "$p" ]; then KEEP+=("$p"); else echo "skipping missing: $p"; fi
    done

    cp -a --parents -t $OUT "${KEEP[@]}"
EOR

# ---------------------------------------------------------------
# Step 2: busybox applets, and the dynamic loader.
# The loader is the one library the lists above leave out. Everything else
# comes from the lists, so nothing extra is copied in by ldd.
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail

    /usr/bin/busybox --install -s $OUT/usr/bin      # every applet goes in /usr/bin
    cp -L --parents /lib64/ld-linux-x86-64.so.2 $OUT
EOR

# ---------------------------------------------------------------
# Step 3: check /out is self-contained. Libraries are resolved against /out only,
# as in the final image. The build stops on any missing file or library.
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail

    CHECK=(
        /usr/lib/piaware/helpers/*  /usr/bin/dump1090-fa  /usr/sbin/nginx  /usr/bin/netstat  /usr/bin/busybox
        $(find $OUT/usr/lib -type f -name '*.so*' | sed "s#^$OUT##")
    )
    for f in "${CHECK[@]}"; do
        [ -e "$OUT$f" ] || { echo "MISSING FILE $f"; exit 1; }
        if chroot $OUT /lib64/ld-linux-x86-64.so.2 --list "$f" 2>/dev/null | grep 'not found'; then
            echo "^ MISSING LIBS for $f"; exit 1
        fi
    done
EOR

######################################################################
# installation layer
# Only the needed files are copied in, so no deleted-file space is left behind.

FROM scratch AS dga-install
COPY --from=build2 /out/ /
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]
