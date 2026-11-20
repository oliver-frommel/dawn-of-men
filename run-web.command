#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$PROJECT_DIR/build/web"

if [ ! -f "$WEB_DIR/index.html" ]; then
  echo "Export the Godot Web preset to build/web/index.html first."
  exit 1
fi

exec python3 - "$WEB_DIR" <<'PYTHON'
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import sys
import webbrowser


class GodotWebHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


handler = partial(GodotWebHandler, directory=sys.argv[1])
with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
    url = f"http://127.0.0.1:{server.server_port}/"
    print(f"Serving Dawn of Men at {url} (Ctrl+C to stop)", flush=True)
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
PYTHON
