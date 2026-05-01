# Golden Helix Fork of `kasmtech/KasmVNC`

This repo is the **server-side** half of our KasmVNC integration. It
produces the `kasmvncserver` deb that gets installed into the
`ghdesktop-*` images. The client-side patches live in our noVNC
submodule (`kasmweb/`) — see [`kasmweb/GOLDENHELIX.md`](kasmweb/GOLDENHELIX.md).

The fork's purpose:
1. Pin a reproducible build of upstream KasmVNC — `1.4.1~gh.<date>`.
2. Point the `kasmweb` submodule at our fork so client + server move
   together.
3. Add the **openurl** feature (open links from inside the desktop in
   the user's native browser via a UnixRelay channel — see
   [`unix/openurl/README.md`](unix/openurl/README.md) for the design).
4. Provide a one-shot `build_deb.sh` for both Debian Bookworm
   (`appstream-core-images`) and Ubuntu Noble (`workspaces-core-images`)
   targets.

## Branch and pinning

- Long-lived branch: **`goldenhelix-master-20260430`** in
  `goldenhelix/KasmVNC`.
- Forked from `kasmtech/KasmVNC` master at `d9b4772` (2026-03-24,
  post-1.4.0, includes VNC-151 hardware-accelerated h.264/h.265/AV1
  encoding via VAAPI, plus Alpine 3.22/3.23, Fedora 42/43, OpenSUSE 16
  build support).
- Rollback tag on the previous fork tip: `pre-master-rebase-20260430`.
- Upstream remote: `git remote add upstream https://github.com/kasmtech/KasmVNC.git`.

## Patches in order (on top of `d9b4772`)

| # | Commit | Subject | Why |
|---|--------|---------|-----|
| 1 | `aeb4b66` | Goldenhelix integration on top of upstream master (1.4.1~gh.20260430) | Three things bundled: (a) `.gitmodules` repointed to `goldenhelix/noVNC` `goldenhelix-master-20260430`; (b) `kasmweb` submodule pointer bumped to that branch; (c) version stamped in `debian/changelog` and `unix/xserver/hw/vnc/xvnc.c` so the deb and the running `Xkasmvnc -version` both report `1.4.1~gh.20260430`. Also (re-)introduces `build_deb.sh`. |
| 2 | `4ac69a1` | Bump kasmweb submodule for RFB URL.toString() fix | Ships the kasmweb fix described in #8 of the noVNC patch list. |
| 3 | `bf0f744` | build_deb.sh: drop sudo | The dev environment has docker in the user group; `sudo docker build` was breaking. |
| 4 | `f1a2a64` | Install openurl wrapper into the kasmvncserver deb | Added: `unix/openurl/{kasmvnc-open-url, kasmvnc-open-url.desktop, README.md}`; `unix/CMakeLists.txt` install rules so the wrapper enters the source tarball at `${BIN_DIR}` and `${DATA_DIR}/applications`; `debian/Makefile.to_fakebuild_tar_package` cp lines so it ends up in the deb staging at `/usr/bin` and `/usr/share/applications`. The `.desktop` file's `Exec=` is `/usr/bin/...` (the deb path). |
| 5 | `3007572` | deb: add python3 + desktop-file-utils | The `kasmvnc-open-url` wrapper is a Python 3 stdlib script, and we need `update-desktop-database` after installing the `.desktop` file. Adds both as runtime `Depends:`. |
| 6 | `14c500e` | openurl: install XFCE helper | When in XFCE, `xdg-open` short-circuits to `exo-open`, which uses XFCE's helper system, not `mimeapps.list`. Adds `unix/openurl/kasmvnc-open-url.helper` which gets installed at `/usr/share/xfce4/helpers/kasmvnc-open-url.desktop`. Set `WebBrowser=kasmvnc-open-url` in `~/.config/xfce4/helpers.rc` to use it. |
| 7 | `f76282f` | openurl: install xdg-open shim | In our headless XFCE setup, `xfce4-mime-helper` wedges on D-Bus activation, so the helper from #6 doesn't always fire. Adds `unix/openurl/xdg-open-shim` which gets installed at `/usr/bin/kasmvnc-xdg-open`; the image dockerfile symlinks `/usr/local/bin/xdg-open → /usr/bin/kasmvnc-xdg-open` so it shadows the system `xdg-open` for http(s). Belt + suspenders + duct tape: `mimeapps.list`, XFCE helper, and shim are all in place. The shim is the load-bearing one. |
| 8 | `1e0e546` | Bump kasmweb submodule for view_only flicker fix | Ships the kasmweb fix described in #10 of the noVNC patch list. |

## Files we touch

| Path | Patch | Why |
|------|-------|-----|
| `.gitmodules` | #1 | Submodule URL → `goldenhelix/noVNC`, branch → `goldenhelix-master-...` |
| `kasmweb` (submodule) | #1, #2, #8 | Pointer bumps. |
| `debian/changelog` | #1 | Version stamp `1.4.1~gh.<date>-1`. |
| `debian/control` | #5 | Added `python3, desktop-file-utils` to runtime depends. |
| `debian/Makefile.to_fakebuild_tar_package` | #4, #6, #7 | Install the openurl bits into the deb. |
| `unix/xserver/hw/vnc/xvnc.c` | #1 | `XVNCVERSION` stamp so `Xkasmvnc -version` matches. |
| `unix/CMakeLists.txt` | #4, #6, #7 | `install()` rules so the openurl bits enter the source tarball. |
| `unix/openurl/` | #4, #6, #7 | New directory: wrapper, .desktop, XFCE helper, xdg-open shim, README. |
| `build_deb.sh` | #1, #3 | Build helper for bookworm + noble targets. |

The codebase upstream is otherwise unchanged. Specifically:
- No changes to `common/`, `unix/xserver/`, or any C++ — the openurl
  feature reuses the existing `-UnixRelay name:path` mechanism.
- No new RFB message types.

## How to rebase to a newer upstream

1. Tag the current tip: `git tag pre-master-rebase-YYYYMMDD goldenhelix-master-20260430`.
2. Pick a new `kasmtech/KasmVNC` SHA. Master is fine if you also
   rebase `kasmweb` to a new noVNC SHA in the same release window.
3. `git checkout -b goldenhelix-master-YYYYMMDD <chosen-sha>`
4. Cherry-pick the 8 patches above. Hot zones:
   - `debian/Makefile.to_fakebuild_tar_package`: upstream may add
     more `cp` lines; preserve our openurl block.
   - `unix/CMakeLists.txt`: trivial; just preserve our `install()`
     rules.
   - `debian/control`: upstream may bump the deps line; merge ours
     in.
   - `debian/changelog`: don't bother trying to merge — write a fresh
     `1.4.1~gh.YYYYMMDD-1` entry on top of whatever upstream has.
   - `kasmweb` submodule: bump to whichever SHA the rebased noVNC
     branch ends up at.
5. `./build_deb.sh ubuntu noble` and `./build_deb.sh debian bookworm`,
   stage the artifacts, rebuild the dependent images.

## How to rebuild end-to-end

The deb consumers are in two locations now:

| Distro / image | Repo | Built tag |
|---|---|---|
| `bookworm` (Debian 12) | `appstream-core-images` → `appstream-images` | `ghdesktop-core` / `ghdesktop-office-web` / `ghdesktop-varseq` etc. |
| `noble` (Ubuntu 24.04) | `workspaces-core-images` → `workspaces-images` | `ghdesktop-core-noble` / `ghdesktop-office-web-noble` |

Order of operations:

```sh
# In KasmVNC repo:
./build_deb.sh debian bookworm   # → ../appstream-core-images/src/kasmvncserver.deb
./build_deb.sh ubuntu noble      # → ../workspaces-core-images/src/kasmvncserver.deb

# In each image repo:
cd ../appstream-core-images && ./build.sh
cd ../appstream-images && ./build_core.sh
cd ../workspaces-core-images && ./build.sh
cd ../workspaces-images && ./build_core.sh
```

## Things upstream now has that we used to need

- **Reconnect default `true`** — was a goldenhelix patch, now upstream.
- **`sendKeepAlive`** — was patched-around in goldenhelix `bad1bdb`,
  now upstream has the right primitive.
- **Webpack removed** — upstream switched to Vite. Don't add back.

## Things to watch on rebase

- **`MAX_UNIX_RELAYS`** in `common/rfb/unixRelayLimits.h` is `4`. With
  printer + smartcard + openurl we use 3 of the 4 slots. If upstream
  adds another relay (audio? something else?) and you push us to 5, bump
  the constant.
- **VAAPI compile-time deps** (`libavcodec`, `libavformat`,
  `libswscale`, `libva`, `libdrm`) need to remain on the deb's
  `Build-Depends`. They're already in
  `builder/dockerfile.debian_bookworm.build` and
  `builder/dockerfile.ubuntu_noble.build`.
- **Lintian "embedded-library libjpeg"** — known and unfixable from
  here; we statically link libjpeg-turbo for performance.
