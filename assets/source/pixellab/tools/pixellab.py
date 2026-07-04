"""Minimal PixelLab MCP client over streamable HTTP (stdlib only)."""
import json
import os
import sys
import urllib.request

URL = "https://api.pixellab.ai/mcp"


def _token():
    cfg = json.load(open(os.path.expanduser("~/.claude.json")))
    def find(o):
        if isinstance(o, dict):
            if "pixellab" in o and isinstance(o["pixellab"], dict) and "headers" in o["pixellab"]:
                return o["pixellab"]["headers"]["Authorization"].split()[-1]
            for v in o.values():
                r = find(v)
                if r:
                    return r
        return None
    return find(cfg)


_rid = [10]


def rpc(method, params=None):
    _rid[0] += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _rid[0], "method": method,
                       "params": params or {}}).encode()
    req = urllib.request.Request(URL, data=body, headers={
        "Authorization": f"Bearer {_token()}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    })
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read().decode()
    # SSE or plain JSON
    for line in raw.splitlines():
        line = line.strip()
        if line.startswith("data: "):
            d = json.loads(line[6:])
            if "result" in d or "error" in d:
                return d
    return json.loads(raw)


def call(tool, args=None):
    d = rpc("tools/call", {"name": tool, "arguments": args or {}})
    if "error" in d:
        raise RuntimeError(d["error"])
    res = d["result"]
    out = []
    for c in res.get("content", []):
        if c.get("type") == "text":
            out.append(c["text"])
    return "\n".join(out), res


def schema(*names):
    d = rpc("tools/list")
    for t in d["result"]["tools"]:
        if t["name"] in names:
            print("=" * 20, t["name"], "=" * 20)
            print(json.dumps(t.get("inputSchema", {}), indent=1)[:4000])


if __name__ == "__main__":
    if sys.argv[1] == "schema":
        schema(*sys.argv[2:])
    elif sys.argv[1] == "call":
        text, _ = call(sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else {})
        print(text)
