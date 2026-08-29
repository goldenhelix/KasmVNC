# Golden Helix Fork of `kasmtech/KasmVNC`

This repo is the **server-side** half of our KasmVNC integration. It
produces the `kasmvncserver` deb that gets installed into the
`ghdesktop-*` images. The client-side patches live in our noVNC
submodule (`kasmweb/`) — see [`kasmweb/GOLDENHELIX.md`](kasmweb/GOLDENHELIX.md).

The fork's purpose:
1. Pin a reproducible build of upstream KasmVNC — `1.5.1~gh.<date>`.
2. Point the `kasmweb` submodule at our fork so client + server move
   together.
3. Add four Unix-relay channels — see
   [`unix/openurl/README.md`](unix/openurl/README.md),
   [`unix/download/README.md`](unix/download/README.md),
   [`unix/upload/README.md`](unix/upload/README.md), and
   `unix/host/kasmvnc-host`.
4. Provide a one-shot `build_deb.sh` for Debian Trixie (the target).

## Branch and pinning

- Long-lived branch: **`goldenhelix-master-20260828`** in
  `goldenhelix/KasmVNC`.
- Forked from `kasmtech/KasmVNC` master at `7b5c304` (2026-08-28),
  which is **post-1.5.1** — it carries upstream releases 1.4.1, 1.4.2,
  1.5.0 and 1.5.1 plus 120 master-only commits.
- Rollback tag: `pre-master-rebase-20260828` (= the previous tip,
  `914cff1`, on the retired `goldenhelix-master-20260430` branch).
- Upstream remote: `git remote add upstream https://github.com/kasmtech/KasmVNC.git`.

### Previous bases

| Branch | Upstream base | Version |
|--------|---------------|---------|
| `goldenhelix-master-20260828` | `7b5c304` (post-1.5.1) | `1.5.1~gh.20260828` |
| `goldenhelix-master-20260430` | `d9b4772` (post-1.4.0) | `1.4.1~gh.20260430` / `…20260513` |

## Patches in order (on top of `7b5c304`)

The 20260430 branch carried 25 commits, ten of which were pure
`kasmweb` submodule-pointer bumps. Those were collapsed into a single
pointer set during the rebase, so the list below is the whole fork.

| # | Commit | Subject | Why |
|---|--------|---------|-----|
| 1 | `5c6534c` | Goldenhelix integration on top of upstream master | `.gitmodules` retargeted to `goldenhelix/noVNC` `goldenhelix-master-20260828`; submodule pointer set; version stamped `1.5.1~gh.20260828` in `debian/changelog` and `unix/xserver/hw/vnc/xvnc.c`. Introduces `build_deb.sh`. |
| 2 | `d6b413f` | build_deb.sh: drop sudo | Dev environment has docker in the user group; `sudo docker build` was breaking permissions. |
| 3 | `0c771da` | Install openurl wrapper into the kasmvncserver deb | Adds `unix/openurl/{kasmvnc-open-url, kasmvnc-open-url.desktop, README.md}` and CMake/Makefile install rules. |
| 4 | `7916e57` | deb: add python3 + desktop-file-utils | The wrapper is a Python 3 stdlib script; `update-desktop-database` is needed after installing the `.desktop` file. |
| 5 | `48ad431` | openurl: install XFCE helper | In XFCE, `xdg-open` short-circuits to `exo-open`, which uses XFCE's helper system, not `mimeapps.list`. |
| 6 | `60db801` | openurl: install xdg-open shim | `xfce4-mime-helper` wedges on D-Bus activation in our headless XFCE, so #5 doesn't always fire. Installs `/usr/bin/kasmvnc-xdg-open`. |
| 7 | `e0b9e52` | Add GOLDENHELIX.md (initial) | Documentation. |
| 8 | `133bcc8` | Install download + upload helpers + Thunar UCA into deb | Adds `unix/{download,upload}/`: `kasmvnc-file-download`, `kasmvnc-upload-daemon`, and `thunar-uca.example.xml`. |
| 9 | `20bae3a` | upload-daemon: named bind + verbose logging | Bind to `/tmp/kasmvnc-upload-daemon-$DISPLAY.sock` rather than a kernel auto-bound abstract address, which Xvnc lost track of across reconnects. Adds `KASMVNC_UPLOAD_LOG_LEVEL`. |
| 10 | `1bc9946` | Refresh GOLDENHELIX.md | Documentation. |
| 11 | `5819d41` | EncodeManager: flush pseudo-encodings in writeLosslessRefresh | See **EncodeManager** below — the commit message is partly obsolete. |
| 12 | `e17b069` | Build pipeline: multi-distro routing | `build_deb.sh` staging targets per (distro, codename). The chown-tolerance half of this commit was dropped on rebase (see #19). |
| 13 | `c79cd3c` | Add download relay scripts + upload daemon docs/service file | |
| 14 | `545c268` | Add iframe test harness for kasmweb embedding | `iframe-test/`. |
| 15 | `eef0906` | Add host UnixRelay channel, bump MAX_UNIX_RELAYS | `unix/host/kasmvnc-host`; `MAX_UNIX_RELAYS` 4 → 8. |
| 16 | `bb57a68` | build_deb.sh: derive VERSION from debian/changelog | The literal went stale on every rebase and failed only at the final staging step, after the slow build. |
| 17 | `4f28fd3` | build_deb.sh: pass OUTPUT_OWNER_UID to the www image build | Upstream's `dockerfile.www.build` now requires it. |
| 18 | `de3d4ec` | build_deb.sh: wipe builder/www before rebuilding | `build-www-inside-docker` plain-`cp`s into `/build` and fails on pre-existing files. |
| 19 | `3765368` | build_deb.sh: follow upstream's reorganised build outputs | See **Upstream build pipeline moved** below. |

## Files we touch

| Path | Patch | Why |
|------|-------|-----|
| `.gitmodules` | #1 | Submodule URL → `goldenhelix/noVNC`, branch → `goldenhelix-master-20260828`. |
| `kasmweb` (submodule) | #1 | Pointer. |
| `debian/changelog` | #1 | Version stamp. **A version site.** |
| `debian/control` | #4 | `python3, desktop-file-utils` in runtime Depends. |
| `debian/Makefile.to_fakebuild_tar_package` | #3, #5, #6, #8, #15 | Install openurl + download + upload + host + Thunar UCA. |
| `unix/xserver/hw/vnc/xvnc.c` | #1 | `XVNCVERSION` stamp. **A version site.** |
| `unix/CMakeLists.txt` | #3, #5, #6, #8, #15 | `install()` rules for the helpers. |
| `unix/openurl/` | #3, #5, #6 | Wrapper, .desktop, XFCE helper, xdg-open shim, README. |
| `unix/download/` | #8, #13 | `kasmvnc-file-download`, Thunar UCA snippet, README. |
| `unix/upload/` | #8, #9, #13 | `kasmvnc-upload-daemon`, service file, README. |
| `unix/host/` | #15 | `kasmvnc-host`. |
| `common/rfb/unixRelayLimits.h` | #15 | `MAX_UNIX_RELAYS` 4 → 8. |
| `common/rfb/EncodeManager.cxx` | #11 | Pseudo-encoding flush in video mode. |
| `build_deb.sh` | #1, #2, #12, #16–#19 | Build helper. Not an upstream file. |
| `iframe-test/` | #14 | Local embedding harness. |

Apart from `EncodeManager.cxx` and `unixRelayLimits.h`, the codebase is
unchanged — no new RFB message types. All four file-transfer features
reuse the existing `-UnixRelay name:path` mechanism.

## EncodeManager (patch #11) — read before touching

The commit message on `5819d41` describes two fixes. Only one of them
still applies:

- **Dropped on rebase:** the `printf("TOTAL FRAME TOOK: …")` removal.
  Upstream replaced that line with an `NDEBUG`-guarded
  `DEBUG_STOPWATCH_PRINT_MSG_MS(vlog, start, "FRAME TOTAL TIME")`
  (`ee942a5`), so there is nothing left to remove. Keep upstream's line.
- **Kept:** the `writeLosslessRefresh()` pseudo-encoding flush. But the
  *stated rationale* (lagging cursor **shape**) is now handled upstream:
  `e324407` (VNC-349) added the cursor-shape flags to
  `SMsgWriter::needNoDataUpdate()`, which flushes those pseudo-rects
  before `writeLosslessRefresh` is reached. The patch is still
  load-bearing for the **other** pseudo-rects that can still be stranded
  in video mode — cursor *position* (warps / game mode), desktop rename,
  and the QEMU-key handshake.

## Upstream build pipeline moved (2026-08 rebase)

Upstream's `VNC-295` (`2836497`) and `VNC-335` (`6b72886`) rewrote the
build driver. What changed, and what `build_deb.sh` now does:

| Was | Now |
|-----|-----|
| `builder/dockerfile.www.build` needed no build args | Requires `--build-arg OUTPUT_OWNER_UID`; without it the build dies with `useradd: invalid user ID ''` |
| Source tarball landed in `/tmp/kasmvnc.<os>_<codename>.tar.gz` | Lands in `builder/build/kasmvnc.<os>_<codename>.tar.gz` |
| Debs landed in `builder/build/<codename>/` | Land in `builder/build/<os>_<codename>/` |
| `build-package` ended with a `chown` that failed under rootless docker | Containers run with `--user`, so outputs are already ours — the old `\|\| true` tolerance is gone (it only masked real failures) |
| `build-package` built only the tarball | Runs `build-tarball` **and** `build-<format>`, so calling `builder/build-deb` afterwards rebuilt the deb twice |

`build_deb.sh` still builds the www bundle itself (step 1) rather than
letting `builder/build-tarball` call `builder/build-www`: that wrapper
does its `mkdir` through `sudo -u`, which we avoid. Because step 1
leaves `builder/www` newer than `kasmweb/`, upstream's `build-www`
then short-circuits with "source did not change" and never reaches the
sudo call. **Keep step 1 ahead of `build-package` for that reason.**

Also new upstream: third-party deps (libyuv, libstatgrab, pinned
fmt/TBB) are fetched and compiled at build time rather than baked into
the builder image, with an `sccache` cache under
`builder/build/.sccache/user_<uid>/<os>_<codename>`. First build after a
rebase is slow and needs egress to `chromium.googlesource.com` and
`github.com`. libyuv is fetched from a moving `stable` branch — the
script honours `LIBYUV_BRANCH` if we ever want to pin it.

## How to rebase to a newer upstream

1. Tag current tip: `git tag pre-master-rebase-YYYYMMDD goldenhelix-master-<current>`.
2. Pick a new `kasmtech/KasmVNC` SHA and read what that revision pins
   `kasmweb` to (`git ls-tree <sha> kasmweb`) — rebase our noVNC fork
   onto that exact SHA so client and server stay a matched pair.
3. **Rebase noVNC first** (see `kasmweb/GOLDENHELIX.md`), then come back
   here and pin the submodule to its new tip.
4. `git checkout -b goldenhelix-master-YYYYMMDD <chosen-sha>`, then
   cherry-pick the patches above in order. Skip pure submodule bumps and
   set the pointer once at the end. Hot zones:
   - `debian/changelog`: write a fresh entry on top of upstream's newest.
   - `unix/xserver/hw/vnc/xvnc.c`: re-stamp `XVNCVERSION` to match.
   - `debian/Makefile.to_fakebuild_tar_package` and
     `unix/CMakeLists.txt`: preserve our install block; upstream has not
     touched either file in a long time.
   - `common/rfb/EncodeManager.cxx`: see the section above.
   - `build_deb.sh`: re-read upstream's `builder/` scripts. This is where
     every rebase actually breaks.
5. `./build_deb.sh debian trixie` and rebuild the dependent images.

## How to rebuild end-to-end

```sh
# In KasmVNC repo:
./build_deb.sh debian trixie   # → ../workspaces-core-images/src/trixie/kasmvncserver.deb

# In each image repo:
cd ../workspaces-core-images && ./build-trixie.sh
cd ../appstream-images && ./build-trixie.sh && ./build-varseq-trixie.sh
```

## Things to watch on rebase

- **`MAX_UNIX_RELAYS = 8`** in `common/rfb/unixRelayLimits.h` (upstream
  is still 4). We use four slots (openurl, download, upload, host).
  Verified unchanged upstream as of `7b5c304`.
- **Subscribe-to-send gating** — Xvnc requires the client to be
  subscribed to a relay name even just to *send* on it. Verified still
  present at `7b5c304`: `VNCSConnectionST::unixRelay()` and the whole
  relay subsystem are byte-identical to `d9b4772`. If we add another
  relay, the JS side must subscribe even with a no-op handler. See
  kasmweb patch #18 — deleting that "dead-looking" line silently breaks
  all uploads with no error on either side.
- **Version ordering.** We stamp `1.5.1~gh.<date>`, and `~` sorts
  *below* plain `1.5.1`, so apt considers our build older than upstream
  1.5.1. That is harmless today (images install the deb by path, no Kasm
  apt repo is configured) but it is wrong. If we ever serve these from a
  repo alongside upstream's, switch to `1.5.1+gh.<date>`.
- **Version sites are three, not two**: `debian/changelog`,
  `unix/xserver/hw/vnc/xvnc.c`, and — historically — `build_deb.sh`.
  Patch #16 made `build_deb.sh` derive from the changelog, so there are
  now two to edit.
- **FFmpeg is dlopen'd by exact SONAME major** (`libavformat.so.<N>`
  etc., majors baked in from the builder image's headers). The runtime
  image must ship the same majors or *all* video streaming modes
  silently disable — see the note in
  `../workspaces-core-images/GOLDENHELIX.md`.
- **VAAPI compile-time deps** (`libavcodec`, `libavformat`,
  `libswscale`, `libva`) remain in `builder/dockerfile.debian_trixie.build`.
- **Lintian "embedded-library libjpeg"** — known and unfixable; we
  statically link libjpeg-turbo for performance.
