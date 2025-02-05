#!/bin/bash

sudo docker build -t kasmweb/www -f builder/dockerfile.www.build .
sudo docker run --rm -v $PWD/builder/www:/build kasmweb/www:latest
./builder/build-package debian bookworm
# To fix  permission issue
cp /tmp/kasmvnc.debian_bookworm.tar.gz builder/build/
./builder/build-deb debian bookworm
cp builder/build/bookworm/kasmvncserver_1.3.2-1_amd64.deb ../appstream-core-images/src/kasmvncserver.deb
