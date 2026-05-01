#!/bin/bash
#
# Build the goldenhelix KasmVNC .deb for Debian Bookworm and stage it for
# the appstream-core-images dockerfile.
#
# Version is set by editing debian/changelog and unix/xserver/hw/vnc/xvnc.c
# directly (see top entry of debian/changelog for the current version).

set -e

VERSION="1.4.1~gh.20260430-1"
ARCH="amd64"
CODENAME="bookworm"

cd "$(dirname "$0")"

# 1. Build the kasmweb (noVNC) bundle into builder/www/
sudo docker build -t kasmweb/www -f builder/dockerfile.www.build .
sudo docker run --rm -v "$PWD/builder/www:/build" kasmweb/www:latest

# 2. Package the source tarball
./builder/build-package debian "$CODENAME"

# Permission workaround: build-package writes to /tmp via docker as root
cp "/tmp/kasmvnc.debian_${CODENAME}.tar.gz" builder/build/

# 3. Build the .deb
./builder/build-deb debian "$CODENAME"

# 4. Stage the deb for appstream-core-images
DEB="builder/build/${CODENAME}/kasmvncserver_${VERSION}_${ARCH}.deb"
if [ ! -f "$DEB" ]; then
  echo "Expected deb not found at $DEB" >&2
  ls -la "builder/build/${CODENAME}/" >&2
  exit 1
fi
cp "$DEB" ../appstream-core-images/src/kasmvncserver.deb
echo "Staged $DEB -> ../appstream-core-images/src/kasmvncserver.deb"
