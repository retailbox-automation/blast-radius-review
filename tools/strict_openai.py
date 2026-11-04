#!/usr/bin/env python3
"""A stand-in for an OpenAI-compatible server that checks messages the way Ollama does.

The first turn of each conversation is an assistant message with empty content and no tool calls,
which is what a local model can return when it stops early or spends its tokens thinking.
A request that carries an assistant message with no content and no tool calls gets HTTP 400 with the
text Ollama 0.40.13 returns. Every request is logged as one JSON line with the status it got.

Usage: strict_openai.py <port> <log file>
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG = sys.argv[2]


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def reply(self, code, obj, msgs):
        with open(LOG, "a") as f:
            f.write(json.dumps({"status": code, "messages": msgs}) + "\n")
        data = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        self.reply(200, {"object": "list", "data": [{"id": "stand-in", "object": "model"}]}, [])

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
        msgs = body.get("messages", [])
        for m in msgs:
            if m.get("role") == "assistant" and m.get("content") is None and not m.get("tool_calls"):
                return self.reply(400, {"error": {"message": "invalid message content type: <nil>",
                                                  "type": "invalid_request_error", "param": None, "code": None}}, msgs)
        first = not any(m.get("role") == "assistant" for m in msgs)
        message = {"role": "assistant", "content": "" if first else "I have nothing more to add."}
        self.reply(200, {"id": "stand-in", "object": "chat.completion", "created": 1, "model": "stand-in",
                         "choices": [{"index": 0, "message": message, "finish_reason": "stop"}],
                         "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}, msgs)


ThreadingHTTPServer(("0.0.0.0", int(sys.argv[1])), Handler).serve_forever()
