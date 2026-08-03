import json
import os
import signal
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def required(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"missing required environment variable: {name}")
    return value


role = required("INFER_ROLE")
node = required("INFER_NODE")
rank = required("INFER_RANK")
world_size = required("INFER_WORLD_SIZE")
stopping = threading.Event()


def request_stop(_signum: int, _frame: object) -> None:
    stopping.set()


signal.signal(signal.SIGINT, request_stop)
signal.signal(signal.SIGTERM, request_stop)

print(
    f"cluster-smoke role={role} node={node} rank={rank} world_size={world_size}",
    flush=True,
)

if role == "head":
    port = int(required("INFER_PORT"))
    body = json.dumps(
        {
            "status": "ok",
            "node": node,
            "role": role,
            "rank": int(rank),
            "worldSize": int(world_size),
        }
    ).encode("utf-8")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path != "/health":
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            return

    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.timeout = 0.5
    while not stopping.is_set():
        server.handle_request()
    server.server_close()
elif role == "worker":
    stopping.wait()
else:
    raise SystemExit(f"unsupported cluster-smoke role: {role}")
