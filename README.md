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
- ***latest*** latest stable build - 76 MB
- ***slim*** - alpaquita version that works except for status - 73 MB
- ***skinny*** - debian version that loads minimum set of dependencies - 61 MB
- ***big*** - debian version that just loads the *.deb file - 181 MB
## Note  
All versions appear to work correctly.  But slim and skinny don't show
the green status boxes on the flightaware my ADS-B status page.  
Interesting note: all version - green status boxes don't show when using safari or firefox.
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
## Acknowledgements
- Thanks to Flightaware for providing the original files
