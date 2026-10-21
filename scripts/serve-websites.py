"""Serve browser-native website fixtures at their canonical development URLs."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import socket
from threading import Thread

ROOT = Path(__file__).resolve().parent.parent / "examples" / "websites"
parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=8000)
parser.add_argument("--ipv6-only", action="store_true", help="Add the IPv6 loopback listener beside an existing IPv4 server")
args = parser.parse_args()

class WebsiteHandler(SimpleHTTPRequestHandler):
    def __init__(self, *values, **options):
        super().__init__(*values, directory=str(ROOT), **options)

    def send_head(self):
        if self.path.split("?", 1)[0] in ("/", "/index.html"):
            self.send_response(302)
            self.send_header("Location", "/wiki1/index.html")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return None
        return super().send_head()

handler = WebsiteHandler

class IPv6LoopbackServer(ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        # Keep the listener local; the IPv4 server binds 127.0.0.1 separately.
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        super().server_bind()

if args.ipv6_only:
    with IPv6LoopbackServer(("::1", args.port), handler) as server:
        print(f"Website server (IPv6 loopback): http://localhost:{args.port}/", flush=True)
        server.serve_forever()
else:
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        try:
            ipv6 = IPv6LoopbackServer(("::1", args.port), handler)
        except OSError as exc:
            print(f"IPv6 loopback unavailable: {exc}", flush=True)
            ipv6 = None
        if ipv6:
            Thread(target=ipv6.serve_forever, daemon=True).start()
        print(f"Website server: http://localhost:{args.port}/", flush=True)
        try:
            server.serve_forever()
        finally:
            if ipv6:
                ipv6.shutdown()
                ipv6.server_close()
