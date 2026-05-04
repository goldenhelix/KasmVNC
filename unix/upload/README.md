# KasmVNC Upload Channel

Drag-and-drop files from the user's machine onto the kasmweb window;
they land in a chosen directory inside the Xvnc desktop session
(default `~/Downloads`). A long-running daemon receives the bytes and
writes them to disk with collision-avoiding dedup.

Built on KasmVNC's `-UnixRelay` mechanism. No protocol or C++ changes.

## How it works

```
  Browser tab                                  Xvnc session
  ─────────────                                ──────────────

  user drags files onto kasmweb
        │
        ▼
  drop overlay → modal             /tmp/kasmvnc-upload-
  (file list,                       $DISPLAY.sock           writes
   dest input                            ▲                  files
   ~/Downloads,                          │                    │
   Upload btn)                           │ recvfrom           │
        │                                │                    ▼
        ▼                                │
  upload.js                       +──────┴────────+    +─────────────+
  - 64 KB slices                  │ Xvnc relay    │───▶│ kasmvnc-    │
  - START/CHUNK/END  ─sendUnix─▶ │ recv from JS  │    │ upload-     │
  - per-file xid     RelayData    │ sendto daemon │    │ daemon      │
                                  +───────────────+    │ (Python)    │
                                                       │ - dedup     │
                                                       │ - mkdir -p  │
                                                       │ - O_EXCL    │
                                                       │ - fsync     │
                                                       +─────────────+
```

Wire format (big-endian):

```
  type:u8  xid:u32  body
    0 START : u64 size  u16+name  u16+mime(unused)  u16+dest_dir
    1 CHUNK : u32 seq   u32 len   bytes
    2 END   : u32 totalSeq
    3 ERROR : u16+msg
    4 CANCEL: (no body)
```

The daemon registers itself by sending a hello byte on startup (so the
Xvnc relay caches its address as the upload peer) and re-sends it every
60 s as belt-and-suspenders.

## Filename collisions

`name.ext` exists → write `name-2.ext`. That exists → `name-3.ext`,
up to `name-999.ext`. The daemon uses `O_CREAT | O_EXCL` to avoid
TOCTOU races between processes.

## What changed in the codebase

### kasmweb (submodule)

- `kasmweb/core/output/upload.js` — drag/drop overlay on `window`,
  modal with file list + destination input, slices each file with
  `File.slice(...).arrayBuffer()` in 64 KiB chunks, sends via
  `rfb.sendUnixRelayData("upload", ...)`.
- `kasmweb/core/output/transfers.js` — shared progress panel.
- `kasmweb/core/rfb.js` — added import and init call next to download.

### KasmVNC repo

- `unix/upload/kasmvnc-upload-daemon` — Python long-running daemon.
  Listens on the upload relay socket, writes incoming chunks to the
  destination dir.
- `unix/upload/kasmvnc-upload-daemon.service` — systemd `--user`
  service unit; pairs with `graphical-session.target`.

## Deploying it

### 1. Install the daemon (once per image)

```sh
install -m 755 kasmvnc-upload-daemon /usr/bin/kasmvnc-upload-daemon
install -m 644 kasmvnc-upload-daemon.service \
    /etc/systemd/user/kasmvnc-upload-daemon.service
```

### 2. Enable as a user service (per user, once)

```sh
systemctl --user enable --now kasmvnc-upload-daemon.service
```

If you don't use systemd `--user`, an alternative is to run the daemon
from your VNC `xstartup`:

```sh
/usr/bin/kasmvnc-upload-daemon &
```

The daemon waits up to 5 minutes for the relay socket to appear, so
ordering relative to Xvnc startup is forgiving.

### 3. Start Xvnc with the relay flag

```
-UnixRelay upload:/tmp/kasmvnc-upload-${DISPLAY#:}.sock
```

For `DISPLAY=:1`, the socket is `/tmp/kasmvnc-upload-1.sock`.

### 4. Optional: max file size

The daemon reads `KASMVNC_UPLOAD_MAX_SIZE` (bytes) from the environment;
default is 4 GiB. Override in the systemd unit (`Environment=`) or
xstartup. Files declared larger than the cap are rejected at START;
files that grow past the cap mid-stream are killed and partials cleaned
up.

## Testing

1. Confirm the daemon is running and registered:
   ```sh
   journalctl --user -u kasmvnc-upload-daemon -f
   # Expect: "upload daemon ready, target=/tmp/..., max_size=..."
   ```
2. From the kasmweb tab, drag any file onto the canvas. The drop
   overlay (blue dashed border, "Drop files to upload") should appear.
3. Drop. Modal lists the files; default dest `~/Downloads`.
4. Click Upload. Floating Transfers panel shows progress per file.
5. Confirm files landed:
   ```sh
   ls -la ~/Downloads/
   ```

## Caveats

- **The daemon must be running.** If it's not, JS sends bytes into a
  void — the server `sendto`s the cached daemon address, gets
  ECONNREFUSED, and drops. From the user's point of view: progress bar
  fills, then nothing happens. Add monitoring on the systemd unit if
  this is critical.
- **No server → client confirmation.** The daemon doesn't ack
  successful writes back to the JS layer. The progress bar reaching
  100% means "JS sent all bytes," not "daemon wrote them all." A future
  v2 could add ACK packets via `rfb.sendUnixRelayData` from the daemon
  (the relay is bidirectional). For now, check the journal.
- **Path safety.** The daemon runs as the user, so it can write
  anywhere the user can. The destination text input has no allowlist —
  if someone types `/etc/foo`, the daemon will try to write there
  (and fail if not writable). For VSWarehouse's threat model
  (authenticated user uploading to their own home dir), this is fine.
- **Backpressure is approximate.** JS yields to the event loop between
  64 KiB chunks (`setTimeout(0)`); the WebSocket flushes on those
  ticks. For very fast clients on slow networks, the websocket buffer
  could grow. Acceptable for typical convenience-upload sizes.
- **Drag-drop captures the whole window.** The `dragenter`/`drop`
  listeners are on `window`, so dragging files anywhere over the
  kasmweb tab triggers the overlay — including drags that started
  inside the X session (which never produces a Files transfer anyway,
  so the overlay just does nothing). Only `Files` drags activate the
  upload flow.
- **Multi-viewer:** the most-recently-active (drag/drop) client owns
  the upload modal; other viewers won't see it. The bytes go to the
  daemon regardless of who initiated.
