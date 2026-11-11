# Author:   D. G. Adams
#
# Date:     2026-Nov-06
#
# Builds and installs piaware, dump1090-fa, and nginx into a single
# "piaware" image. Three stages: build, install, and scratch.

#######################################################################
# Stage 1: build the dump1090-fa and piaware .deb packages
#######################################################################
FROM debian:trixie-slim AS build

# Build dump1090-fa
RUN <<EOR
    set -e
    apt-get update
    apt-get -yq install \
        build-essential debhelper fakeroot git libncurses-dev \
        librtlsdr-dev pkg-config

    git clone https://github.com/flightaware/dump1090.git /dump1090
    cd /dump1090
    dpkg-buildpackage -b --no-sign --build-profiles=custom,rtlsdr
EOR

# Build piaware
RUN <<EOR
    set -e
    apt-get -yq install \
        autoconf devscripts libz-dev net-tools openssl patchelf wget \
        tcl8.6-dev libncurses6 librtlsdr0 \
        libboost-filesystem-dev libboost-program-options-dev \
        libboost-regex-dev libboost-system-dev \
        python3-build python3-dev python3-filelock python3-pip \
        python3-pyasyncore python3-setuptools python3-venv python3-wheel

    git clone https://github.com/flightaware/piaware_builder.git
    cd /piaware_builder
    ./sensible-build.sh trixie
    cd package-trixie
    dpkg-buildpackage -b --no-sign
EOR

#######################################################################
# Stage 2: install piaware and its dependencies into a clean Debian,
# which leaves the build artifacts behind. Then fix up permissions and
# connect piaware to dump1090-fa. The final filesystem is staged in /out.
#######################################################################
FROM debian:trixie-slim AS install

WORKDIR /dump1090
COPY --from=build /piaware_builder/piaware_*_amd64.deb piaware.deb
COPY --from=build /dump1090/public_html/ public_html/
COPY --from=build /dump1090/debian/dump1090-fa/usr/bin/dump1090-fa \
     /usr/bin/


RUN <<EOR
    apt-get -yq update
    apt-get -yq install /dump1090/piaware.deb
    apt-get -yq install nginx libusb-1.0-0 librtlsdr0 libncurses6 busybox
    apt-get clean
    rm -rf /dump1090/piaware.deb /etc/nginx

    # Basic piaware and dump1090-fa setup
    # (the piaware package usually creates this user already)
    id piaware >/dev/null 2>&1 || \
        adduser --no-create-home --disabled-login --disabled-password piaware
    mkdir /run/dump1090 /var/run/piaware /var/cache/piaware
    touch /etc/piaware.conf public_html/upintheair.json
    echo "{}" > public_html/db/~.json

    # Compress the web files (upintheair.json must stay readable as is)
    find public_html -type f ! -name upintheair.json \
         \( -name '*.json' -o -name '*.js' \
            -o -name '*.css' -o -name '*.svg' \) \
         -exec gzip -9 {} +

    # Let the unprivileged piaware user write where it needs to
    chown -R piaware \
        /run/dump1090 /run/piaware /var/cache/piaware \
        /var/log/nginx /var/lib/nginx
    chown piaware /etc/piaware.conf public_html
EOR

#----------------------------------------------------------------------
# Build the final filesystem in /out by copying IN only what is needed.
# Nothing is deleted, so scratch gets a minimal, clean filesystem.
#
#   Step 1: copy in the files listed below
#   Step 2: add the busybox applets and the dynamic loader
#   Step 3: check that /out is self-contained
#
# cp -a keeps the piaware ownership set above.
#----------------------------------------------------------------------
ENV OUT=/out

# piaware.sh, nginx.conf, etc.
COPY files/* /out/dump1090/

# Replaces the stock tcllib pkgIndex.tcl, which describes every tcllib
# module and so expects directories we remove. This one sources the index
# of each module that is present. It runs at load time, so the modules
# trimmed below are simply skipped.
COPY <<'EOT' /out/usr/share/tcltk/tcllib2.0/pkgIndex.tcl
set tcllib_dir $dir
foreach index [glob -nocomplain -directory $tcllib_dir */pkgIndex.tcl] {
    set dir [file dirname $index]
    source $index
}
set dir $tcllib_dir
EOT

# ---------------------------------------------------------------------
# Step 1: create the directory layout, then copy in the listed paths.
# Paths are relative to /; cp --parents recreates each one under /out.
# Missing paths are skipped and reported ("skipping missing" in the log).
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail
    shopt -s nullglob       # a glob that matches nothing is dropped

    # --- /out layout: Debian-style symlinks ---
    mkdir -p $OUT/lib64 $OUT/var $OUT/tmp
    chmod 1777 $OUT/tmp
    ln -s usr/lib  $OUT/lib
    ln -s usr/bin  $OUT/bin
    ln -s usr/sbin $OUT/sbin
    ln -s ../run   $OUT/var/run

    cd /
    LIB=usr/lib/x86_64-linux-gnu

#   Every binary needed
    BINS=(
        usr/bin/busybox usr/bin/dump1090-fa usr/bin/netstat usr/bin/piaware
        usr/bin/tcl* usr/sbin/nginx
    )

    # Every library the image needs is named here; step 3 fails the build
    # if one is missing. ld-linux is left out: step 2 adds it.
    LIBS=(
        usr/lib/Tcl* usr/lib/fa_* usr/lib/libtclx* usr/lib/os-release
        usr/lib/piaware usr/lib/piaware_packages usr/lib/ssl usr/lib/tcl*

        # C library, compression, regex, xml
        $LIB/libc.* $LIB/libm.* $LIB/libresolv.* $LIB/libpthread.*
        $LIB/libcrypt.* $LIB/libz.* $LIB/libzstd.* $LIB/libpcre2*
        $LIB/libexpat.*

        # TLS, nginx, netstat
        $LIB/libssl.* $LIB/libcrypto.* $LIB/libcap* $LIB/libselinux.*
        $LIB/libncurses.* $LIB/libtinfo*

        # dongle access, mlat and tcl
        $LIB/libusb* $LIB/libudev* $LIB/librtlsdr.*
        $LIB/libpython* $LIB/libtcl8.6.* $LIB/libitcl*
    )

    # tcltk: everything except tcllib2.0 and tcl8.6, which are trimmed.
    # (tcllib2.0/pkgIndex.tcl comes from the COPY above.)
    TCL=(
        $(find usr/share/tcltk -mindepth 1 -maxdepth 1 \
              ! -name tcllib2.0 ! -name tcl8.6)
        usr/share/tcltk/tcllib2.0/{json,aes,cmdline,0compatibility}
        $(find usr/share/tcltk/tcl8.6 -mindepth 1 -maxdepth 1 \
              ! -name msgs ! -name tzdata ! -name encoding)
        usr/share/tcltk/tcl8.6/encoding/{ascii,iso8859-1,cp1252}.enc
    )

    # Data, and the directories piaware and nginx write to
    DATA=(
        usr/share/nginx usr/share/piaware etc/passwd etc/group etc/piaware*
        var/cache/piaware var/log/nginx var/lib/nginx run/dump1090 run/piaware
        dump1090/public_html
    )

    # Keep only the paths that exist, and report the ones that do not
    KEEP=()
    for p in "${BINS[@]}" "${LIBS[@]}" "${TCL[@]}" "${DATA[@]}"; do
        if [ -e "$p" ]; then
            KEEP+=("$p")
        else
            echo "skipping missing: $p"
        fi
    done

    cp -a --parents -t $OUT "${KEEP[@]}"
EOR

# ---------------------------------------------------------------------
# Step 2: busybox applets and the dynamic loader. The loader is the one
# library the lists above leave out; nothing else is copied in by ldd.
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail

    /usr/bin/busybox --install -s $OUT/usr/bin
    cp -L --parents /lib64/ld-linux-x86-64.so.2 $OUT
EOR

# ---------------------------------------------------------------------
# Step 3: check that /out is self-contained. Libraries are resolved
# against /out only, as in the final image. Stops on any missing file
# or library.
RUN <<'EOR'
#!/bin/bash
    set -euo pipefail

    check() {
        [ -e "$OUT$1" ] || { echo "MISSING FILE $1"; exit 1; }
        if chroot $OUT /lib64/ld-linux-x86-64.so.2 --list "$1" \
               2>/dev/null | grep 'not found'; then
            echo "^ MISSING LIBS for $1"
            exit 1
        fi
    }

    for f in /usr/lib/piaware/helpers/* \
             /usr/bin/dump1090-fa /usr/sbin/nginx \
             /usr/bin/netstat /usr/bin/busybox; do
        check "$f"
    done

    for f in $(find $OUT/usr/lib -type f -name '*.so*'); do
        check "${f#$OUT}"
    done
EOR

#######################################################################
# Stage 3: the final image. Only the needed files are copied in, so no
# deleted-file space is left behind.
#######################################################################
FROM scratch AS dga-install

COPY --from=install /out/ /
USER piaware
WORKDIR /dump1090
CMD ["/dump1090/piaware.sh"]
