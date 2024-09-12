Piaware Docker image

Built for AMD64 (not raspberry pi)

This image includes:
    dump1090-fa as dump1090 with only rtlsdr libraries 
    nginx web server - including SSL certificates linked in using docker volumes
                       exposes ports 8080 http, and 8443 https
    piaware 9.0.1

Usually run using docker compose yml file:

name: piaware
services:
  piaware:
    container_name: piaware
    image: piaware:latest
    restart: unless-stopped
    init: true
    ports:
      - 8080:8080
      - 8443:8443
    devices:
      - /dev/bus/usb
    volumes:
       - ~/.certs:/etc/certs
    environment:
      FEEDER_ID: "your feeder id here"
      RECEIVER_LON: "your longitute"
      RECEIVER_LAT: "your latitude"
      RECEIVER: "rtlsdr"
      JSON_LOCATION_ACCURACY: 2 
