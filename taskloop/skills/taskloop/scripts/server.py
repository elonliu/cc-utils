"""Minimal HTTP server for taskloop HTML view data sync."""

import argparse
import json
import os
import signal
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path


DATA_FILE = "taskloop-data.json"
DEFAULT_PORT = 8765


class TaskloopHandler(SimpleHTTPRequestHandler):
    """Handle static files + /api/tasks REST endpoints."""

    data_path: Path | None = None

    def do_GET(self):
        if self.path == "/api/tasks":
            self._serve_json()
        elif self.path == "/" or self.path == "/index.html":
            self._serve_html()
        else:
            super().do_GET()

    def _serve_html(self):
        html_path = Path("template.html")
        if html_path.exists():
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(html_path.read_bytes())
        else:
            self.send_error(404, "template.html not found")

    def do_POST(self):
        if self.path == "/api/tasks":
            self._save_json()
        else:
            self.send_error(404)

    def _serve_json(self):
        if self.data_path and self.data_path.exists():
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(self.data_path.read_bytes())
        else:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"tasks":[],"updated_at":""}')

    def _save_json(self):
        if not self.data_path:
            self.send_error(500, "No data path configured")
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body)
            if not isinstance(data, dict):
                raise ValueError("Expected JSON object")
            self.data_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
        except (json.JSONDecodeError, ValueError) as e:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def log_message(self, format, *args):
        sys.stderr.write(f"[taskloop] {format % args}\n")


def find_port(start=DEFAULT_PORT, max_tries=10):
    """Find an available port starting from DEFAULT_PORT."""
    for i in range(max_tries):
        port = start + i
        try:
            with HTTPServer(("127.0.0.1", port), TaskloopHandler):
                pass
            return port
        except OSError:
            continue
    raise RuntimeError(f"No available port in range {start}-{start + max_tries - 1}")


def main():
    parser = argparse.ArgumentParser(description="Taskloop HTTP server")
    parser.add_argument("--port", type=int, default=0, help="Port (0 = auto-detect)")
    parser.add_argument("--dir", type=str, default=".", help="Serve directory (default: current)")
    args = parser.parse_args()

    serve_dir = Path(args.dir).resolve()
    if not serve_dir.is_dir():
        print(f"Error: directory {serve_dir} not found", file=sys.stderr)
        sys.exit(1)

    data_path = serve_dir / DATA_FILE

    port = args.port if args.port > 0 else find_port()
    TaskloopHandler.data_path = data_path

    os.chdir(serve_dir)
    server = HTTPServer(("127.0.0.1", port), TaskloopHandler)

    print(f"[taskloop] Server running at http://127.0.0.1:{port}")
    print(f"[taskloop] Data file: {data_path}")
    print(f"[taskloop] Press Ctrl+C to stop")

    try:
        signal.signal(signal.SIGTERM, lambda s, f: server.shutdown())
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
        print("[taskloop] Server stopped")


if __name__ == "__main__":
    main()
