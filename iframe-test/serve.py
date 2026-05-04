#!/usr/bin/env python3
"""Tiny dev server for the kasmweb iframe test harness.

Just `python3 serve.py` and open http://localhost:8124. The kasmvnc
container should be running separately on https://localhost:6904 (or
edit the URL in index.html's first input).

Why a separate page (not just opening index.html via file://)? Browsers
treat file:// origins as opaque and refuse to run an iframe pointing at
https://localhost — the iframe just doesn't load. http://localhost is a
real origin and works.
"""
import http.server
import os
import socketserver
import sys

PORT = int(os.environ.get("PORT", 8124))


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Allow this page to embed cross-origin iframes (kasmvnc is on
        # a different port). Without these the browser blocks the load.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin-allow-popups")
        self.send_header("Cross-Origin-Embedder-Policy", "unsafe-none")
        super().end_headers()


os.chdir(os.path.dirname(os.path.abspath(__file__)))
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"iframe test harness on http://localhost:{PORT}", file=sys.stderr)
    print("Ctrl-C to stop", file=sys.stderr)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
