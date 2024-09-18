# Piaware Docker image

## Built for AMD64 (not raspberry pi)

## This image includes:
- dump1090-fa 
    - built as dump1090 from flightware sources.
    - only built with rtlsdr libraries. 
- nginx web server 
    -  exposes ports 8080 http.
- piaware 9.0.1
    - built from flightware source.
## Tags
- ***Latest*** - latest stable build

## Notes
- This version is now running in alpaquita. A multi-stage build is implemented. 
The following stages are done in the Dockerfile (build, install):
    - build: dump1090 is built
    - build: piaware is built
    - build: piaware is installed
    - build: libraries needed for piaware are saved
    - build: Binaries needed are saved
    - install: The image is base is Alpaquita
    - install: Libraries and Binaries are copied from build.
    - install: Everything is configured 

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
## Acknowledgements
- Thanks to Flightaware for providing the original files
