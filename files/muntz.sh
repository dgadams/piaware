#!/bin/bash
# This script uses a feature of bash - extglob which allows rm !(exception_list) to
# selectively remove any file in the current image layer except those listed.
# Used for muntzing libraries and files down to the minimal set needed to run the application.

shopt -s extglob

#   remove all library directories except ...
    cd /usr/lib
    EXCEPT="!(Tcl*|fa_*|libtclx*"
    EXCEPT+="|os-release|piaware|piaware_packages"
    EXCEPT+="|ssl|tcl*|terminfo|udev|x86_64*"
    EXCEPT+=")"
    rm -rf $EXCEPT

#   remove all libraries except ...
    cd /usr/lib/x86_64-linux-gnu
    EXC="!(libc.*|ld-linux*"                        # basic c library
    EXC+="|libresolv.*"                             # needed for busybox
    EXC+="|libtcl8.6.*|libz.*|libm.*"               # needed for piaware
    EXC+="|libcrypt*|librtlsdr.*|libusb*|libudev*"  # or dump1090-fa
    EXC+="|libpcre2*|libncurses.*|libpthread.*|libssl.*"
    EXC+="|libitcl*|libselinux.*|libexpat.*|libtinfo*"
    EXC+="|liblzma.*|libzstd.*|libbz2.*|libmd.*"    # needed for dpkg utility
    EXC+=")"
    rm -fr $EXC

#   Nuke some other stuff
    rm -rf /var/lib/dpkg/info/*
    rm -rf /var/lib/apt/lists/*
    rm -rf /var/cache/debconf/*
    cd /etc && rm -rf !(passwd|group|gshadow|shadow|piaware*)
    cd /usr/share && rm -rf !(ca*|debconf|locale|nginx|piaware|tcltk)

#   remove /usr/sbin except for nginx
    cd /usr/sbin && rm -rf !(nginx)

#   remove stuff from /usr/bin.
#   both dpkg and netstat are used by piaware
    cd /usr/bin
    rm -rf !(busybox|dpkg*|dump1090-fa|netstat|piaware|pirehose|tcl*)


