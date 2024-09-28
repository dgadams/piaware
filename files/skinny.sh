#!/bin/bash

#   remove unneeded files - do a little muntzing.
#   This works in conjuction with the filesystem build layer to allow
#   us to remove any file from the debian distribution

#   This is rather ugly and was created by iteratively removing and testing
#   until things broke.  Then put it back.  This is called muntzing.

#   remove /usr/sbin with exceptions
cd /usr/sbin
KEEP='adduser|nginx'
ls | grep -xvE $KEEP | xargs rm -f

#   Nuke some other big stuff
rm -rf /var/lib/dpkg/info/*
rm -rf /var/cache/debconf/*
rm -rf /usr/share/doc
rm -rf /usr/share/zoneinfo
rm -rf /usr/share/perl5
rm -rf /usr/share/common-licenses

#   Now we tackle libraries
rm -rf /usr/lib/apt
rm -rf /usr/lib/systemd
rm -rf /usr/lib/piaware-config
rm -rf /usr/lib/piaware-status

cd /usr/lib/x86_64-linux-gnu
KEEP='libc.so.6|libz.so.1|libz.so.1.2.13|libm.so.6|ld-linux-x86-64.so.2'
KEEP+='|libtcl8.6.so|libtcl8.6.so.0'
KEEP+='|libcrypt.so.1.1.0|libcrypt.so.1|libssl.so.3|libcrypto.so.3'
KEEP+='|libpcre2-8.so.0|libpcre2-8.so.0.11.2'
KEEP+='|librtlsdr.so.0|librtlsdr.so.0.6.0'
KEEP+='|libncurses.so.6|libncurses.so.6.4'
KEEP+='|libtinfo.so.6|libtinfo.so.6.4'
KEEP+='|libusb-1.0.so.0|libusb-1.0.so.0.3.0'
KEEP+='|libudev.so.1|libudev.so.1.7.5'
KEEP+='|libpthread.so.0|libitcl3.4.so.1'
KEEP+='|libselinux.so.1'
KEEP+='|libexpat.so.1|libexpat.so.1.8.10'
KEEP+='|libresolv.so.2'
ls | grep -xvE $KEEP | xargs rm -rf

#   remove stuff from /usr/bin.  Have to be careful here.
cd /usr/bin
#KEEP='bash|busybox|chown|mkdir|rm|ls|grep|xargs|echo|sh|dash'
KEEP='bash|busybox|rm|ls|grep|xargs|sh|dash'
KEEP+='|dump1090-fa|piaware|pirehose|tcllauncher|netstat'
ls | grep -xvE $KEEP | xargs rm -rf

#   Do some busybox links
rm ls rm grep xargs
busybox ln -s busybox ln
ln -s busybox ls
ln -s busybox rm
ln -s busybox chown
ln -s busybox mkdir
ln -s busybox echo
ln -s busybox uname
