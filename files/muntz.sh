#!/bin/bash

shopt -s extglob        # bash extension to allow rm -rf !(except_file|...)

#   remove all library directories except ...
cd /usr/lib
    EXCEPT="!(Tcl*|fa_*|libtclx*"
    EXCEPT+="|os-release|piaware|piaware_packages"
    EXCEPT+="|ssl|tcl*|terminfo|udev|x86_64*"
    EXCEPT+=")"
rm -rf $EXCEPT

#   remove all libraries except ...
cd /usr/lib/x86_64-linux-gnu
    EXC="!(libc.*|ld-linux*|libresolv.*"
    EXC+="|libtcl8.6.*|libz.*|libm.*"                   # needed for piaware
    EXC+="|libcrypt*|librtlsdr.*|libusb*|libudev*"      # or dump1090-fa
    EXC+="|libpcre2*|libncurses.*|libpthread.*|libssl.*"
    EXC+="|libitcl*|libselinux.*|libexpat.*|libtinfo*"
    EXC+="|liblzma.*|libzstd.*|libbz2.*|libmd.*)"       # needed for dpkg utility
rm -fr $EXC

# Selectively removing stuff
rm -rf /var/lib/dpkg/info/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/debconf/*
cd /etc         && rm -rf !(passwd|group|gshadow|shadow|piaware*)
cd /usr/share   && rm -rf !(ca*|debconf|locale|nginx|piaware|tcltk)
cd /usr/sbin    && rm -rf !(nginx)
cd /usr/bin     && rm -rf !(busybox|dpkg*|dump1090-fa|netstat|piaware|pirehose|tcl*)
