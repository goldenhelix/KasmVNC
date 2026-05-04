#!/bin/bash
#
# Build the goldenhelix KasmVNC .deb and stage it for the gh image
# repos.
#
# Usage:
#   ./build_deb.sh                # default: debian bookworm -> appstream-core-images
#   ./build_deb.sh debian bookworm
#   ./build_deb.sh ubuntu noble   # -> workspaces-core-images
#
# Version is set by editing debian/changelog and unix/xserver/hw/vnc/xvnc.c
# directly (see top entry of debian/changelog for the current version).

set -e

VERSION="1.4.1~gh.20260430-1"
ARCH="amd64"
DISTRO="${1:-debian}"
CODENAME="${2:-bookworm}"

# Where to stage the produced .deb. Each (distro, codename) pair maps to
# the image repo that consumes it.
case "${DISTRO}_${CODENAME}" in
    debian_bookworm)
        STAGE_DIR="../appstream-core-images/src"
        ;;
    debian_trixie)
        STAGE_DIR="../workspaces-core-images/src/trixie"
        ;;
    ubuntu_noble)
        STAGE_DIR="../workspaces-core-images/src"
        ;;
    ubuntu_jammy)
        STAGE_DIR="../workspaces-core-images/src/jammy"
        ;;
    *)
        echo "Unknown ${DISTRO}_${CODENAME}; staging skipped." >&2
        STAGE_DIR=""
        ;;
esac

cd "$(dirname "$0")"

# 1. Build the kasmweb (noVNC) bundle into builder/www/
docker build -t kasmweb/www -f builder/dockerfile.www.build .
docker run --rm -v "$PWD/builder/www:/build" kasmweb/www:latest

# 2. Package the source tarball.
#
# build-package's last step is `chown $L_UID:$L_GID /tmp/kasmvnc.*.tar.gz`,
# which fails under rootless docker (the file ends up owned by some
# subuid that the host user can't chown). The build itself is done at
# that point, so we tolerate that specific failure and re-stage the
# tarball with cp (which doesn't require ownership match).
./builder/build-package "$DISTRO" "$CODENAME" || true

TARBALL="/tmp/kasmvnc.${DISTRO}_${CODENAME}.tar.gz"
if [ ! -f "$TARBALL" ]; then
    echo "Source tarball missing: $TARBALL — build-package failed earlier than expected." >&2
    exit 1
fi
cp "$TARBALL" "builder/build/kasmvnc.${DISTRO}_${CODENAME}.tar.gz"

# 3. Build the .deb
./builder/build-deb "$DISTRO" "$CODENAME"

# 4. Stage the deb
DEB="builder/build/${CODENAME}/kasmvncserver_${VERSION}_${ARCH}.deb"
if [ ! -f "$DEB" ]; then
  echo "Expected deb not found at $DEB" >&2
  ls -la "builder/build/${CODENAME}/" >&2
  exit 1
fi

if [ -n "$STAGE_DIR" ]; then
  mkdir -p "$STAGE_DIR"
  cp "$DEB" "$STAGE_DIR/kasmvncserver.deb"
  echo "Staged $DEB -> $STAGE_DIR/kasmvncserver.deb"
else
  echo "Built $DEB (not staged)"
fi
