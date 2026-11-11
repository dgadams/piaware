#!/bin/sh
set -e

# Environment variables that can be passed in from docker:
#   FEEDER_ID               piaware feeder id (optional)
#   RECEIVER_SERIAL         dongle serial or index (--device-index)
#   RECEIVER_GAIN           receiver gain
#   MAX_RANGE               maximum range
#   ERROR_CORRECTION        "yes" enables --fix
#   JSON_LOCATION_ACCURACY  JSON location accuracy
#   RECEIVER_LAT/LON        receiver position (both are needed)

# Write piaware.conf fresh on every start, so a restart cannot pile up
# duplicate lines. Updates are off: there is no package manager here.
{
    if [ -n "$FEEDER_ID" ]; then echo "feeder-id $FEEDER_ID"; fi
    echo "allow-auto-updates no"
    echo "allow-mlat yes"
    echo "mlat-results yes"
} > /etc/piaware.conf

# Options dump1090 needs for proper operation
set -- --quiet --device-type rtlsdr \
    --net-ro-port 30002 --net-sbs-port 30003 \
    --net-bi-port 30004,30104 --net-bo-port 30005 \
    --adaptive-range --write-json /run/dump1090

# Options passed in from docker
[ -z "$RECEIVER_SERIAL" ] || set -- "$@" --device-index "$RECEIVER_SERIAL"
[ -z "$RECEIVER_GAIN" ]   || set -- "$@" --gain "$RECEIVER_GAIN"
[ -z "$MAX_RANGE" ]       || set -- "$@" --max-range "$MAX_RANGE"
[ "$ERROR_CORRECTION" != "yes" ] || set -- "$@" --fix
[ -z "$JSON_LOCATION_ACCURACY" ] ||
    set -- "$@" --json-location-accuracy "$JSON_LOCATION_ACCURACY"
if [ -n "$RECEIVER_LAT" ] && [ -n "$RECEIVER_LON" ]; then
    set -- "$@" --lat "$RECEIVER_LAT" --lon "$RECEIVER_LON"
fi

# Start everything up. piaware runs last, in the foreground, as PID 1.
dump1090-fa "$@" &
nginx -g 'pid /run/dump1090/nginx.pid;' -c /dump1090/nginx.conf
exec piaware -p /run/piaware/piaware.pid -plainlog \
    -statusfile /run/piaware/status.json
