# Piaware Docker image

## Built for AMD64 (not raspberry pi)

## This image includes:
- dump1090-fa 
    - built as dump1090 from flightware sources.
    - only built with rtlsdr libraries. 
- nginx web server 
    -  exposes ports 8080 http.
- piaware 10.0
    - built from flightware source.
## Tags
- ***latest*** latest stable build - 76 MB
## building
- docker buildx build -t piaware:latest .
- docker buildx build -t piaware:slim -f dockerfiles/slim .

### Usually run using docker compose yml file:
```
name: piaware
services:
  piaware:
    container_name: piaware
    image: piaware:latest
    restart: unless-stopped
    init: true
    ports:
      - 8080:8080
    devices:
      - /dev/bus/usb
    environment:
      FEEDER_ID: "your feeder id here"
      RECEIVER_LON: "your longitude"
      RECEIVER_LAT: "your latitude"
      RECEIVER: "rtlsdr"
      JSON_LOCATION_ACCURACY: 2 
```
## How I run piaware
I run the application as a Docker container.  Computer is a Dell Wyse 3040 thin client with 2G of memory and 8G of emmc disk.  I'm using Alpine Linux as the base OS for size, but Debian works just as well.
## Acknowledgements
- Thanks to Flightaware for providing the original files
