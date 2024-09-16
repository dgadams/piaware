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
## Notes
- full build of piaware with dump1090 and nginx.
    - 181 MB 
- Problems
    - In some ways this is a terrible build.
    dump1090 is generally ok, but piaware is unacceptable.
    I build piaware just to get the .deb file for the next stage.
    Then install using the .deb file.  It should be possilbe to
    move files from the piaware build directly into the install.
    The piaware files are rather complicated and tough to figure out.
## Acknowledgements
- Thanks to Flightaware for providing the original files
