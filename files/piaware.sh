#!/bin/sh
# Container entrypoint: writes piaware.conf, then starts dump1090-fa,
# nginx and piaware.
#
# Environment variables that can be passed in from docker:
#   FEEDER_ID               piaware feeder id (optional)
#   RECEIVER_SERIAL         dongle serial or index (--device-index)
#   RECEIVER_GAIN           receiver gain in dB
#   MAX_RANGE               maximum range
#   ERROR_CORRECTION        "yes" enables --fix
#   JSON_LOCATION_ACCURACY  JSON location accuracy (0, 1 or 2)
#   RECEIVER_LAT/LON        receiver position (both are needed)

set -eu

CONF=/etc/piaware.conf          # symlink to /run/piaware/piaware.conf
RUN_DIR=/run/piaware
JSON_DIR=/run/dump1090

# All variables are optional; default them so "set -u" doesn't trip.
FEEDER_ID=${FEEDER_ID:-}
RECEIVER_SERIAL=${RECEIVER_SERIAL:-}
RECEIVER_GAIN=${RECEIVER_GAIN:-}
MAX_RANGE=${MAX_RANGE:-}
ERROR_CORRECTION=${ERROR_CORRECTION:-}
JSON_LOCATION_ACCURACY=${JSON_LOCATION_ACCURACY:-}
RECEIVER_LAT=${RECEIVER_LAT:-}
RECEIVER_LON=${RECEIVER_LON:-}

die() { echo "piaware.sh: $*" >&2; exit 1; }

# Fail early on a typo ("60db") instead of a cryptic dump1090 error.
# An empty value passes: the option is simply skipped below.
check_number() {
    case $2 in
        *[!0-9.-]*) die "$1 must be a number, got '$2'" ;;
    esac
}
check_number RECEIVER_GAIN          "$RECEIVER_GAIN"
check_number MAX_RANGE              "$MAX_RANGE"
check_number JSON_LOCATION_ACCURACY "$JSON_LOCATION_ACCURACY"
check_number RECEIVER_LAT           "$RECEIVER_LAT"
check_number RECEIVER_LON           "$RECEIVER_LON"

# ---- piaware.conf --------------------------------------------------
# Written fresh on every start, so a restart cannot pile up duplicate
# lines. Updates are off: there is no package manager here.
mkdir -p "$RUN_DIR"
{
    [ -z "$FEEDER_ID" ] || echo "feeder-id $FEEDER_ID"
    echo "allow-auto-updates no"
    echo "allow-mlat yes"
    echo "mlat-results yes"
} > "$CONF"

# ---- dump1090-fa options -------------------------------------------
# Options dump1090 needs for proper operation
set -- --quiet --device-type rtlsdr \
    --net-ro-port 30002 --net-sbs-port 30003 \
    --net-bi-port 30004,30104 --net-bo-port 30005 \
    --adaptive-range --write-json "$JSON_DIR"

# Options passed in from docker
[ -z "$RECEIVER_SERIAL" ] || set -- "$@" --device-index "$RECEIVER_SERIAL"
[ -z "$RECEIVER_GAIN" ]   || set -- "$@" --gain "$RECEIVER_GAIN"
[ -z "$MAX_RANGE" ]       || set -- "$@" --max-range "$MAX_RANGE"
[ "$ERROR_CORRECTION" != "yes" ] || set -- "$@" --fix
[ -z "$JSON_LOCATION_ACCURACY" ] ||
    set -- "$@" --json-location-accuracy "$JSON_LOCATION_ACCURACY"

# Position needs both halves; say so if only one was given.
if [ -n "$RECEIVER_LAT" ] && [ -n "$RECEIVER_LON" ]; then
    set -- "$@" --lat "$RECEIVER_LAT" --lon "$RECEIVER_LON"
elif [ -n "$RECEIVER_LAT$RECEIVER_LON" ]; then
    echo "piaware.sh: need both RECEIVER_LAT and RECEIVER_LON; ignoring" >&2
fi

# ---- start everything ----------------------------------------------
dump1090-fa "$@" &
DUMP1090_PID=$!

nginx -g "pid $JSON_DIR/nginx.pid;" -c /dump1090/nginx.conf

# Don't start piaware against a dongle that failed to open: wait for
# dump1090 to produce data, and bail out (so docker restarts us) if it
# dies or stays silent for 30 seconds.
tries=0
until [ -s "$JSON_DIR/aircraft.json" ]; do
    kill -0 "$DUMP1090_PID" 2>/dev/null || die "dump1090-fa exited"
    tries=$((tries + 1))
    [ "$tries" -le 30 ] || die "dump1090-fa produced no data"
    sleep 1
done

# piaware runs last, in the foreground, so it receives docker's signals.
exec piaware -p "$RUN_DIR/piaware.pid" -plainlog \
    -statusfile "$RUN_DIR/status.json"