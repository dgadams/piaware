#!/bin/bash

#   remove unneeded files - do a little muntzing.
#   This works in conjuction with the filesystem build layer to allow
#   us to remove any file from the debian distribution

#   This is rather ugly and was created by iteratively removing and testing
#   until things broke.  Then put it back.  This is called muntzing.
shopt -s extglob

#   Now we tackle libraries
	cd /usr/lib
	rm -rf !(x86_64-linux-gnu|tcl*|libtcl*|Tcl*|piaware|piaware_packages|fa*)

# 	remove all libraries except ...
	cd /usr/lib/x86_64-linux-gnu
	EXC="!(libc.*|ld-linux*"                                # basic c library
	EXC+="|libtinfo*"                                       # needed for bash
#	EXC+="|libselinux*|libacl.*|libattr.*|libpcre*"         # needed for cp
	EXC+="|libresolv.*"                                     # needed for busybox
	EXC+="|libtcl8.6.*|libz.*|libm.*"						# needed for piaware
	EXC+="|libcrypt*|librtlsdr.*|libusb*|libudev*"
	EXC+="|libpcre2*|libncurses.*|libpthread.*|libssl.*"
	EXC+="|libitcl*|libselinux.*|libexpat.*|libtinfo*"
	EXC+=")"
	rm -fr $EXC

#   Nuke some misc stuff
	rm -rf /var/lib/dpkg
	rm -rf /var/lib/apt
	rm -rf /var/cache/debconf
	rm -rf /var/cache/apt
	cd /usr/share && rm -rf !(tcltk|piaware)

	# And last remove everything from sbin but nginx 
	# and everything from bin except busybox piaware and dump1090fa.
	cd /usr/sbin && rm -rf !(nginx)
	cd /usr/bin  && rm -rf !(busybox|piaware|dump1090-fa|netstat)
