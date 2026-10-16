"""Minimal PixelLab MCP client over streamable HTTP (stdlib only)."""
import json
import os
import sys
import urllib.request

URL = "https://api.pixellab.ai/mcp"


def _token(env_path=None, config_path=None):
    """Project-local credential first; legacy Claude config remains supported.

    Never confuse the Gemini art key with the independent PixelLab credential.
    No credentials are logged or copied into project MCP configuration.
    """
    import pathlib
    import shlex
    names = ("PIXELLAB_API_KEY", "PIXELLAB_TOKEN")
    for name in names:
        if os.environ.get(name):
            return os.environ[name]
    env_file = pathlib.Path(env_path) if env_path is not None else pathlib.Path(__file__).resolve().parents[4] / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            name, sep, value = line.strip().removeprefix("export ").partition("=")
            if sep and name.strip() in names:
                words = shlex.split(value, comments=True)
                if words:
                    return words[0]
    cfg_path = pathlib.Path(config_path) if config_path is not None else pathlib.Path.home() / ".claude.json"
    if cfg_path.exists():
        cfg = json.loads(cfg_path.read_text())
        def find(o):
            if isinstance(o, dict):
                entry = o.get("pixellab")
                if isinstance(entry, dict):
                    header = entry.get("headers", {}).get("Authorization", "")
                    if header.startswith("Bearer "):
                        return header[7:]
                for v in o.values():
                    found = find(v)
                    if found:
                        return found
            return None
        found = find(cfg)
        if found:
            return found
    raise RuntimeError("PixelLab credential unavailable. Set PIXELLAB_API_KEY in the gitignored project .env or environment; Gemini's VAEL_ART_API_KEY is separate.")


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
