#!/bin/bash

#   remove unneeded files - do a little muntzing.
#   This works in conjuction with the filesystem build layer to allow
#   us to remove any file from the debian distribution

#   This is rather ugly and was created by iteratively removing and testing
#   until things broke.  Then put it back.  This is called muntzing.

#   remove /usr/sbin with exceptions
    cd /usr/sbin
    ls | grep -xvE 'adduser|nginx' | xargs rm -f

#   remove stuff from /usr/bin.  Have to be careful here.
    cd /usr/bin
    rm -rf [ apt* arch b2sum base* chage chcon chfn chrt chsh cksum
    rm -rf find* gp* grep gzip h* i* lo* lsblk lscpu lsfd lsipc lsirq
    rm -rf lslocks lslogins lsmem lsns mawk mkfifo mknod mount
    rm -rf newgrp nice nl nstat numfmt od partx perl* pr* ptx
    rm -rf rdma re* sc* se* sha* shred shuf sleep sort split ss stat stdbuf
    rm -rf stty sync ta* test tic tsort ucl* umount unshare up* vdir
    rm -rf w* x* y* z* piaware-config piaware-status
#   enough now getting into the 20K and less stuff.

#   Now we tackle libraries
    rm -rf /usr/lib/apt
    rm -rf /usr/lib/systemd
    rm -rf /usr/lib/piaware-config
    rm -rf /usr/lib/piaware-status

    rm -rf /lib/x86_64-linux-gnu/perl-base
    rm -rf /lib/x86_64-linux-gnu/krb5
    rm -rf /lib/x86_64-linux-gnu/gconv

    rm -rf /lib/x86_64-linux-gnu/libsystemd*
    rm -rf /lib/x86_64-linux-gnu/libsmartcols*
    rm -rf /lib/x86_64-linux-gnu/libreadline*
    rm -rf /lib/x86_64-linux-gnu/libp11-kit*
    rm -rf /lib/x86_64-linux-gnu/libkrb5*
    rm -rf /lib/x86_64-linux-gnu/libicu*
    rm -rf /lib/x86_64-linux-gnu/libgnutls*
    rm -rf /lib/x86_64-linux-gnu/libdb*
    rm -rf /lib/x86_64-linux-gnu/libboost*
    rm -rf /lib/x86_64-linux-gnu/libnettle*
    rm -rf /lib/x86_64-linux-gnu/libmvec*
    rm -rf /lib/x86_64-linux-gnu/libndn2*
    rm -rf /lib/x86_64-linux-gnu/libcuuc*
    rm -rf /lib/x86_64-linux-gnu/libgmp*
    rm -rf /lib/x86_64-linux-gnu/libbpf*
    rm -rf /lib/x86_64-linux-gnu/libapt*
    rm -rf /lib/x86_64-linux-gnu/libxxhash*
    rm -rf /lib/x86_64-linux-gnu/libtirpc*
    rm -rf /lib/x86_64-linux-gnu/libnsl*
    rm -rf /lib/x86_64-linux-gnu/libhogweed*
    rm -rf /lib/x86_64-linux-gnu/libgssapi*
    rm -rf /lib/x86_64-linux-gnu/liblzma5*
    rm -rf /lib/x86_64-linux-gnu/libffi*
    rm -rf /lib/x86_64-linux-gnu/libunistring*
    rm -rf /lib/x86_64-linux-gnu/libmount*
    rm -rf /lib/x86_64-linux-gnu/libblkid*
    rm -rf /lib/x86_64-linux-gnu/libgcrypt*

#   Nuke some other big stuff
    rm -rf /var/lib/dpkg/info/*
    rm -rf /var/cache/debconf/*
    rm -rf /usr/share/doc
    rm -rf /usr/share/zoneinfo
    rm -rf /usr/share/perl5
    rm -rf /usr/share/common-licenses
