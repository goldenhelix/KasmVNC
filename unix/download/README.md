# KasmVNC Download Channel

Streams a file or folder from inside the Xvnc desktop session out to the
KasmVNC web client, which triggers a native browser download. Wired up as
a Thunar (xfce file manager) right-click "Download" action.

Built on KasmVNC's `-UnixRelay` mechanism. No protocol or C++ changes.

## How it works

```
   Thunar right-click → "Download"          Browser
       │                                       ▲
       │ Exec=kasmvnc-file-download %F         │ <a download>.click()
       ▼                                       │
  +-----------------------+              +-----+----------+
  | kasmvnc-file-download |              | download.js     |
  |  - file: stream raw   |              |  - reassembles  |
  |  - dir : zip+stream   |  UnixRelay   |    chunks       |
  |  - chunks 64 KB       |─────name─────▶  by xid         |
  |  - START/CHUNK/END    |  "download"  |  - Blob → click │
  +----------▲------------+              +-----------------+
             │
   /tmp/kasmvnc-download-$DISPLAY.sock
        (datagram unix socket
         opened by Xvnc with
         -UnixRelay download:...)
```

Wire format (big-endian, one datagram per envelope):

```
  type:u8  xid:u32  body
    0 START : u64 size  u16+name  u16+mime  u16+dest(unused)
    1 CHUNK : u32 seq   u32 len   bytes
    2 END   : u32 totalSeq
    3 ERROR : u16+msg
```

`size = 0` means unknown (used for streaming zips of folders, though we
currently zip to a tempfile so size is known). Chunk size is 64 KiB.

## What changed in the codebase

### kasmweb (submodule)

- `kasmweb/core/output/download.js` — subscribes to relay name `download`,
  buffers chunks per xid, builds a Blob and triggers
  `<a download>.click()` to launch the browser's native download flow.
- `kasmweb/core/output/transfers.js` — shared floating progress panel
  used by both download and upload.
- `kasmweb/core/rfb.js` — added imports and init calls next to printer /
  smartcard / openurl.

### KasmVNC repo

- `unix/download/kasmvnc-file-download` — Python script. For files,
  streams the bytes; for folders, zips to a tempfile (`tempfile.mkstemp`
  with `.zip` suffix), streams the zip, unlinks. Multiple paths can be
  passed; each becomes its own transfer.
- `unix/download/thunar-uca.example.xml` — Thunar custom-action snippet
  that adds a "Download" right-click entry. Merges into
  `~/.config/Thunar/uca.xml`.

## Deploying it

### 1. Install the script (once per image)

```sh
install -m 755 kasmvnc-file-download /usr/bin/kasmvnc-file-download
```

### 2. Add the Thunar custom action (per user, once)

If the user has no `~/.config/Thunar/uca.xml`, drop the example file in:

```sh
mkdir -p ~/.config/Thunar
install -m 644 thunar-uca.example.xml ~/.config/Thunar/uca.xml
```

If they already have one, merge the `<action>` block in. Restart Thunar
or log out/in for the new entry to appear.

### 3. Start Xvnc with the relay flag

Add to whatever launches Xvnc:

```
-UnixRelay download:/tmp/kasmvnc-download-${DISPLAY#:}.sock
```

For `DISPLAY=:1`, the socket is `/tmp/kasmvnc-download-1.sock`.

### 4. Iframe sandbox (VSWarehouse)

The kasmweb iframe must allow programmatic downloads. In your iframe
sandbox attribute:

```html
<iframe sandbox="allow-same-origin allow-scripts allow-popups
                 allow-forms allow-modals allow-downloads" ...>
```

Without `allow-downloads`, `<a download>.click()` is silently suppressed
by the browser.

## Testing

From inside the desktop session, with Xvnc running with the flag and a
kasmweb client connected:

```sh
# Single file
/usr/bin/kasmvnc-file-download /etc/hosts

# A folder (zipped)
/usr/bin/kasmvnc-file-download ~/Documents

# Multiple
/usr/bin/kasmvnc-file-download a.txt b.pdf ~/some-dir
```

The browser should pop a save dialog (or auto-save to the user's
configured download folder, depending on browser settings) for each.
A floating "Transfers" panel in the bottom-right shows progress.

## Caveats

- **Folder zip is RAM-cheap, disk-bound.** We zip to `/var/tmp` (or
  wherever `tempfile.gettempdir()` points), so disk space matters more
  than RAM for huge folders. ZIP_DEFLATED is used.
- **No cancel.** Once started, the script runs to completion. Closing
  the kasmweb tab during a transfer just drops the data on the floor on
  the JS side; the script keeps emitting until done.
- **Progress UI is browser-side only.** The script doesn't know whether
  the JS handler received the bytes. Successful return ≠ user got the
  file (e.g., if no client was connected when it ran).
- **Memory ceiling on the JS side.** The downloaded file is fully in JS
  memory until the Blob is created and saved. Browsers handle ~2 GB
  comfortably; multi-GB downloads may exhaust the tab. For files larger
  than ~1 GB, prefer your main app's file manager.
- **Concurrent downloads** are supported (each gets its own xid). The
  Transfers panel shows them all.
- **Multi-viewer:** every connected primary-display client receives the
  bytes — i.e., both viewers would download the same file. With the
  read-only viewer URL param, spectators are still primary-display in
  this sense.
