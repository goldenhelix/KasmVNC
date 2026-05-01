# KasmVNC Open-URL Channel

Forwards `http://` / `https://` URLs from inside an Xvnc desktop session out
to the KasmVNC web client, which opens them in a native browser tab on the
user's machine. Replaces the default behavior of launching a browser inside
the desktop.

Built on KasmVNC's existing **UnixRelay** mechanism — the same channel used
by `printer.js` and `smartcard.js`. No new RFB message types, no protocol
changes, no C++ recompile.

## How it works

```
  +-------------------------+        +----------------------+
  |  App in Xvnc desktop    |        |  Browser (kasmweb)   |
  |  (e.g. VarSeq)          |        |                      |
  |    |                    |        |    ^                 |
  |    | clicks link        |        |    | window.open()   |
  |    v                    |        |    | (or postMessage |
  |  xdg-open https://...   |        |    |  to parent)     |
  |    |                    |        |    |                 |
  |    v                    |        |    |                 |
  |  kasmvnc-open-url       |        |  openurl.js handler  |
  |    | (writes URL to     |        |    ^                 |
  |    |  unix dgram sock)  |        |    |                 |
  |    v                    |        |    | UnixRelay msg   |
  |  /tmp/kasmvnc-openurl-  |        |    |                 |
  |  $DISPLAY.sock          |        |    |                 |
  |    |                    |        |    |                 |
  +----|--------------------+        +----|-----------------+
       |                                  |
       |    Xvnc (-UnixRelay openurl:...) |
       +----------------------------------+
              relays bytes via existing
              UnixRelay RFB message
```

1. App calls `xdg-open https://example.com` (or `$BROWSER`, GTK link click,
   etc.).
2. xdg-mime routes the http/https scheme to our `.desktop` file, which runs
   `kasmvnc-open-url <url>`.
3. The wrapper validates the scheme is http(s), then writes the URL to the
   per-display Unix datagram socket at `/tmp/kasmvnc-openurl-$DISPLAY.sock`.
4. Xvnc (started with `-UnixRelay openurl:/tmp/kasmvnc-openurl-...sock`) is
   listening on that socket and wraps the bytes in a `UnixRelay` RFB
   message named `openurl`.
5. All connected kasmweb clients receive the message. Any client subscribed
   to the relay name `openurl` gets the URL via its handler.
6. The handler in `kasmweb/core/output/openurl.js`:
   - **Standalone** (no iframe): calls `window.open(url, "_blank",
     "noopener,noreferrer")`.
   - **Embedded** (in an iframe, e.g. VSWarehouse): does
     `parent.postMessage({action: "openurl", value: url}, "*")` and lets the
     parent decide. Matches the existing kasmweb-fork postMessage pattern
     used for `connection_state`, `clipboardrx`, `fullscreen`, etc.

## What changed in the codebase

### kasmweb (submodule, fork branch)

- `kasmweb/core/output/openurl.js` — new file. ~25 lines. Subscribes to the
  `openurl` UnixRelay name, validates the scheme on the JS side too, then
  either postMessages the parent or calls `window.open`.
- `kasmweb/core/rfb.js` — two lines: import `initializeOpenUrlRelay` (next
  to the existing `initializePrinterRelay` / `initializeSmartcardRelay`
  imports), and call it from the same place those are called (currently
  inside `_handleSecurityResult`, ~line 3232, marked "Register pipe based
  extensions").

### KasmVNC repo

- `unix/openurl/kasmvnc-open-url` — Python wrapper. Validates http(s)
  scheme, looks up `$DISPLAY`, sends the URL to the per-display Unix
  datagram socket. No third-party deps; stdlib only.
- `unix/openurl/kasmvnc-open-url.desktop` — `.desktop` file registering the
  wrapper as the system handler for `x-scheme-handler/http` and
  `x-scheme-handler/https`.
- `unix/openurl/README.md` — this file.

No changes to KasmVNC's C++ code. No new RFB message types. Existing
`-UnixRelay name:path` flag (documented in `unix/xserver/hw/vnc/Xvnc.man`)
is the wire-level channel.

## Deploying it

These steps belong in whatever VSWarehouse uses to provision a session
(systemd unit, container entrypoint, xstartup, etc.). Per-session, since
`$DISPLAY` is per-session.

### 1. Install the wrapper and desktop file (once per image)

```sh
install -m 755 kasmvnc-open-url /usr/local/bin/kasmvnc-open-url
install -m 644 kasmvnc-open-url.desktop /usr/share/applications/kasmvnc-open-url.desktop
update-desktop-database /usr/share/applications  # refresh MIME cache
```

### 2. Make it the default http/https handler (per user, once)

Run as the desktop user:

```sh
xdg-mime default kasmvnc-open-url.desktop x-scheme-handler/http
xdg-mime default kasmvnc-open-url.desktop x-scheme-handler/https
```

This writes to `~/.config/mimeapps.list`. To verify:

```sh
xdg-mime query default x-scheme-handler/https
# → kasmvnc-open-url.desktop
```

### 3. Start Xvnc with the relay flag

Add `-UnixRelay openurl:/tmp/kasmvnc-openurl-${DISPLAY#:}.sock` to whatever
launches Xvnc. The display number must match what `kasmvnc-open-url` sees
in `$DISPLAY` — the wrapper does `lstrip(":").split(".")[0]`, so for
`DISPLAY=:1` it expects the socket at `/tmp/kasmvnc-openurl-1.sock`.

Note `MAX_UNIX_RELAYS = 4` in `common/rfb/unixRelayLimits.h`. With printer
and smartcard already using two slots, `openurl` is the third. Bump the
constant if you add more.

### 4. (Optional) Tell kasmweb's parent frame how to handle the message

In VSWarehouse, the iframe parent will receive:

```js
window.addEventListener("message", (e) => {
    if (e.data && e.data.action === "openurl") {
        window.open(e.data.value, "_blank", "noopener,noreferrer");
    }
});
```

Make sure the iframe's `sandbox` attribute includes `allow-popups` (the
existing `kasmweb/example_iframe.html` already does).

If you don't add a parent listener, nothing happens when the user is in a
VSWarehouse iframe — the message is just discarded. That's intentional:
the parent app decides the URL-open policy.

## Testing

From inside the desktop session, with Xvnc started with the relay flag and
a kasmweb client connected:

```sh
# Manual test — bypasses xdg-open:
/usr/local/bin/kasmvnc-open-url https://example.com

# End-to-end test via xdg-open:
xdg-open https://example.com

# The browser tab should pop on the user's machine, not inside the desktop.
```

If nothing happens, check in order:
- `ls /tmp/kasmvnc-openurl-*.sock` — does the socket exist? (Xvnc not
  started with the flag, or wrong path.)
- Browser console — do you see `Popup blocked for ...` warning? (User must
  allow popups for the kasmweb origin once.)
- Browser console — any other errors from `openurl.js`?
- `xdg-mime query default x-scheme-handler/https` — is it
  `kasmvnc-open-url.desktop`?

## Caveats

- **Popup blocker.** Modern browsers block `window.open` from non-gesture
  contexts. The user must allow popups for the kasmweb origin once
  (one-time browser dialog). When embedded in VSWarehouse, the parent
  handles the open in response to the postMessage event, which counts as a
  user-initiated action in many browsers — less of a problem.
- **Multi-viewer broadcast.** If two browsers are connected to the same
  session, both will get the message. Fine for VSWarehouse single-user app
  streaming. For multi-user view-only setups, only the writer is likely
  triggering URL opens, but spectators will also pop tabs.
- **Scheme allowlist.** The wrapper rejects everything except `http://`
  and `https://`. The JS handler also re-validates. Any process inside the
  desktop can write to the socket; restricting to http(s) means no
  `javascript:`, `data:`, `file:` smuggling.
- **No bidirectional state.** This is one-way (desktop → browser). The
  browser doesn't ack receipt; if no client is connected when a URL is
  emitted, it's dropped. For app-streaming where a client is always
  connected during use, this is fine.
- **Two URLs in quick succession.** Each becomes its own datagram, its own
  RFB message, its own `window.open` call. Browsers may batch popup
  prompts. Not common in practice.

## Why this design

The `-UnixRelay` mechanism was already in KasmVNC for printer/smartcard
forwarding — exactly the same shape of problem (data from inside the
desktop to the browser). Reusing it means:

- Zero changes to the RFB protocol or KasmVNC's C++.
- Zero divergence in our fork at the protocol layer (no rebased patches to
  maintain across upstream KasmVNC releases).
- The pattern is already understood by anyone familiar with how printer.js
  works.

If the feature ever needs bidirectional flow (browser → desktop response
to a URL), the existing `sendUnixRelayData` JS API gives us the return
path with no further protocol changes.
