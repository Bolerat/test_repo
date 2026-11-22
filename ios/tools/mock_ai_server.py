#!/usr/bin/env python3
"""Mock OpenAI-compatible server for Covey UI tests.

Listens on 127.0.0.1:8799 and answers POST /v1/chat/completions with a fixed
Pawly reply. The iOS Simulator shares the Mac's network, so the app can reach
it as http://localhost:8799/v1. The last request body is written to
/tmp/covey_mock_last_request.json for inspection.
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

REPLY = "Pawly mock 回复：布丁最近状态不错，喂食和换水按时完成就很好，继续保持。"
LAST_REQUEST = "/tmp/covey_mock_last_request.json"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)
        if self.path.rstrip("/").endswith("/chat/completions"):
            try:
                with open(LAST_REQUEST, "wb") as f:
                    f.write(body)
            except OSError:
                pass
            payload = {
                "id": "chatcmpl-mock",
                "object": "chat.completion",
                "created": 0,
                "model": "mock-model",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": REPLY},
                        "finish_reason": "stop",
                    }
                ],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
            }
            data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):  # keep test output clean
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8799), Handler).serve_forever()
