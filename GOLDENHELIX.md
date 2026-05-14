# Golden Helix Fork of `kasmtech/KasmVNC`

This repo is the **server-side** half of our KasmVNC integration. It
produces the `kasmvncserver` deb that gets installed into the
`ghdesktop-*` images. The client-side patches live in our noVNC
submodule (`kasmweb/`) — see [`kasmweb/GOLDENHELIX.md`](kasmweb/GOLDENHELIX.md).

The fork's purpose:
1. Pin a reproducible build of upstream KasmVNC — `1.4.1~gh.<date>`.
2. Point the `kasmweb` submodule at our fork so client + server move
   together.
3. Add three Unix-relay file-transfer channels — see
   [`unix/openurl/README.md`](unix/openurl/README.md),
   [`unix/download/README.md`](unix/download/README.md),
   [`unix/upload/README.md`](unix/upload/README.md).
4. Provide a one-shot `build_deb.sh` for Debian Trixie (the target).

## Branch and pinning

- Long-lived branch: **`goldenhelix-master-20260430`** in
  `goldenhelix/KasmVNC`.
- Forked from `kasmtech/KasmVNC` master at `d9b4772` (2026-03-24,
  post-1.4.0, includes VNC-151 hardware-accelerated h.264/h.265/AV1
  encoding via VAAPI).
- Rollback tag: `pre-master-rebase-20260430`.
- Upstream remote: `git remote add upstream https://github.com/kasmtech/KasmVNC.git`.

## Patches in order (on top of `d9b4772`)

| # | Commit | Subject | Why |
|---|--------|---------|-----|
| 1 | `aeb4b66` | Goldenhelix integration on top of upstream master | `.gitmodules` retargeted to `goldenhelix/noVNC` `goldenhelix-master-20260430`; submodule pointer bumped; version stamped `1.4.1~gh.20260430` in `debian/changelog` and `unix/xserver/hw/vnc/xvnc.c`. Re-introduces `build_deb.sh`. |
| 2 | `4ac69a1` | Bump kasmweb for RFB URL.toString() fix | Carries the kasmweb fix described in #8 of the kasmweb patch list. |
| 3 | `bf0f744` | build_deb.sh: drop sudo | Dev environment has docker in the user group; `sudo docker build` was breaking permissions. |
| 4 | `f1a2a64` | Install openurl wrapper into the kasmvncserver deb | Adds `unix/openurl/{kasmvnc-open-url, kasmvnc-open-url.desktop, README.md}` and CMake/Makefile install rules so the wrapper enters the deb at `/usr/bin` and `/usr/share/applications`. |
| 5 | `3007572` | deb: add python3 + desktop-file-utils | The wrapper is a Python 3 stdlib script; we need `update-desktop-database` after installing the `.desktop` file. Both added to runtime `Depends:`. |
| 6 | `14c500e` | openurl: install XFCE helper | When in XFCE, `xdg-open` short-circuits to `exo-open` which uses XFCE's helper system, not `mimeapps.list`. Adds `unix/openurl/kasmvnc-open-url.helper` installed at `/usr/share/xfce4/helpers/kasmvnc-open-url.desktop`. |
| 7 | `f76282f` | openurl: install xdg-open shim | In our headless XFCE, `xfce4-mime-helper` wedges on D-Bus activation, so the helper from #6 doesn't always fire. Adds `unix/openurl/xdg-open-shim` installed at `/usr/bin/kasmvnc-xdg-open`; the image dockerfile symlinks `/usr/local/bin/xdg-open` to it so it shadows system xdg-open for http(s). |
| 8 | `1e0e546` | Bump kasmweb for view_only flicker fix | Ships #10 of kasmweb. |
| 9 | `81b533d` | Add GOLDENHELIX.md (initial) | Documentation. |
| 10 | `0665ae4` | Bump kasmweb for display clamp + upload/download relays | Ships #11–#12 of kasmweb. |
| 11 | `9bd2f12` | Bump kasmweb for second-screen sidebar hide | Ships #13 of kasmweb. |
| 12 | `535b74e` | Bump kasmweb for softer disconnect message | Ships #14 of kasmweb. |
| 13 | `7268b1a` | Install download + upload helpers + Thunar UCA into deb | Adds `unix/{download,upload}/` directories: `kasmvnc-file-download` (Python; streams files or zip-of-folder to JS), `kasmvnc-upload-daemon` (Python; receives uploaded chunks, writes to disk), and `thunar-uca.example.xml` (right-click "Download" entry). Wired into CMake + Makefile so they install at `/usr/bin/...` and `/usr/share/kasmvnc/thunar-uca.xml`. |
| 14 | `385e776` | Bump kasmweb for upload modal cleanup + destination | Ships #16 of kasmweb. |
| 15 | `a7fd586` | Bump kasmweb for codec notification suppression | Ships #17 of kasmweb. |
| 16 | `eff8b69` | upload-daemon: named bind + verbose logging | Bind to `/tmp/kasmvnc-upload-daemon-$DISPLAY.sock` (named) instead of relying on the kernel's auto-bound abstract address — Xvnc has been observed to lose track of those across client reconnect cycles. New `KASMVNC_UPLOAD_LOG_LEVEL` env var enables DEBUG without redeploy. |
| 17 | `c233979` | Bump kasmweb for upload subscribe fix | Ships #18 of kasmweb. The previous bug: drag-drop uploads "completed" but no bytes ever reached the daemon — Xvnc gates client→daemon forwarding on the client being subscribed to the relay name, even for outbound. |

## Files we touch

| Path | Patch | Why |
|------|-------|-----|
| `.gitmodules` | #1 | Submodule URL → `goldenhelix/noVNC`, branch → `goldenhelix-master-20260430`. |
| `kasmweb` (submodule) | many | Pointer bumps. |
| `debian/changelog` | #1 | Version stamp `1.4.1~gh.20260430-1`. |
| `debian/control` | #5 | Added `python3, desktop-file-utils` to runtime depends. |
| `debian/Makefile.to_fakebuild_tar_package` | #4, #6, #7, #13 | Install openurl + download + upload + Thunar UCA. |
| `unix/xserver/hw/vnc/xvnc.c` | #1 | `XVNCVERSION` stamp matches the deb. |
| `unix/CMakeLists.txt` | #4, #6, #7, #13 | `install()` rules for the helpers. |
| `unix/openurl/` | #4, #6, #7 | Wrapper, .desktop, XFCE helper, xdg-open shim, README. |
| `unix/download/` | #13 | `kasmvnc-file-download` (Python), Thunar UCA snippet, README. |
| `unix/upload/` | #13, #16 | `kasmvnc-upload-daemon` (Python), `kasmvnc-upload-daemon.service`, README. |
| `build_deb.sh` | #1, #3 | Build helper. Knows about Debian (bookworm/trixie) and Ubuntu (jammy/noble) staging targets but trixie is the only one we maintain. |

The codebase upstream is otherwise unchanged — no C++ changes, no
new RFB message types. The three new file-transfer features all reuse
the existing `-UnixRelay name:path` mechanism.

## How to rebase to a newer upstream

1. Tag current tip: `git tag pre-master-rebase-YYYYMMDD goldenhelix-master-20260430`.
2. Pick a new `kasmtech/KasmVNC` SHA. Pair with a same-window noVNC
   rebase.
3. `git checkout -b goldenhelix-master-YYYYMMDD <chosen-sha>`.
4. Cherry-pick the 17 patches above. Hot zones:
   - `debian/Makefile.to_fakebuild_tar_package`: upstream may add more
     `cp` lines; preserve our openurl/download/upload block.
   - `unix/CMakeLists.txt`: trivial; preserve our `install()` rules.
   - `debian/control`: upstream may bump deps; merge ours in.
   - `debian/changelog`: write a fresh `1.4.1~gh.YYYYMMDD-1` entry on
     top.
   - `kasmweb` submodule: bump to whichever SHA the rebased noVNC
     branch ends up at.
5. `./build_deb.sh debian trixie` and rebuild the dependent images.

## How to rebuild end-to-end

```sh
# In KasmVNC repo:
./build_deb.sh debian trixie   # → ../appstream-core-images/src/trixie/kasmvncserver.deb

# In each image repo:
cd ../appstream-core-images && ./build-trixie.sh
cd ../appstream-images && ./build-trixie.sh && ./build-varseq-trixie.sh
```

## Things to watch on rebase

- **`MAX_UNIX_RELAYS = 8`** in `common/rfb/unixRelayLimits.h` (bumped
  from upstream's 4). We currently use four slots (openurl, download,
  upload, host). Headroom for future channels; if upstream adds a
  default relay (audio?) we still fit.
- **VAAPI compile-time deps** (`libavcodec`, `libavformat`,
  `libswscale`, `libva`, `libdrm`) need to remain on the deb's
  `Build-Depends`. Already in `builder/dockerfile.debian_trixie.build`.
- **Lintian "embedded-library libjpeg"** — known and unfixable; we
  statically link libjpeg-turbo for performance.
- **Subscribe-to-send gating** — Xvnc requires the client to be
  subscribed to a relay name even just to *send* on it (see kasmweb
  patch #18). If we add another relay, JS side must subscribe even
  with a no-op handler.
