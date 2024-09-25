#!/bin/bash
set -e

# paste environment into piaware.conf
echo "feeder-id ${FEEDER_ID-}"      >> /etc/piaware.conf
echo "allow-auto-updates yes"        >> /etc/piaware.conf
echo "allow-mlat yes"               >> /etc/piaware.conf
echo "mlat-results yes"             >> /etc/piaware.conf

# default options for dump1090
# these options are necessary for proper operation of dump1090.
OPTS=" --quiet"
OPTS="$OPTS --device-type rtlsdr"
OPTS="$OPTS --net-ro-port 30002"
OPTS="$OPTS --net-sbs-port 30003"
OPTS="$OPTS --net-bi-port 30004,30104"
OPTS="$OPTS --net-bo-port 30005"
OPTS="$OPTS --adaptive-range"
OPTS="$OPTS --write-json /run/dump1090"

# environmental variables that can be passed in from docker.
# RECEIVER_SERIAL
# RECEIVER_GAIN
# MAX_RANGE
# ERROR_CORRECTION yes
# JSON_LOCATION_ACCURACY
# RECEIVER_LAT
# RECEIVER_LON

# passed in options for dump1090
if [ -n "$RECEIVER_SERIAL" ]; then OPTS="$OPTS --device-index $RECEIVER_SERIAL"; fi
if [ -n "$RECEIVER_GAIN"   ]; then OPTS="$OPTS --gain $RECEIVER_GAIN"; fi
if [ -n "$MAX_RANGE"       ]; then OPTS="$OPTS --max-range $MAX_RANGE"; fi
if [ "$ERROR_CORRECTION" = "yes" ]; then OPTS="$OPTS --fix"; fi
if [ -n "$JSON_LOCATION_ACCURACY" ]; then 
    OPTS="$OPTS --json-location-accuracy $JSON_LOCATION_ACCURACY"
fi
if [ -n "$RECEIVER_LAT" -a -n "$RECEIVER_LON" ]; then
    OPTS="$OPTS --lat $RECEIVER_LAT --lon $RECEIVER_LON"
fi

# start everything up
dump1090-fa $OPTS &
nginx -g 'pid /run/dump1090/nginx.pid;' -c '/dump1090/nginx.conf'
#exec piaware -debug -statusfile /run/piaware/status.json
exec piaware -p /run/piaware/piaware.pid -plainlog -statusfile /run/piaware/status.json
