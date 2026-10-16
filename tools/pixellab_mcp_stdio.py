#!/usr/bin/env python3
"""Credential-aware stdio adapter to PixelLab's real streamable-HTTP MCP tools.

Used by Codex/Claude: no key in command arguments/config and no Claude-file
requirement. PixelLab's HTTP endpoint is stateless (the established client).
Only stdio initialization/ping are local; tool schemas/results come unchanged
from the authenticated upstream server. Never log credentials to stdout.
"""
from __future__ import annotations

import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'assets/source/pixellab/tools'))
import pixellab


def respond(message: dict) -> dict | None:
    if 'id' not in message:  # initialized/cancelled notifications have no reply
        return None
    result = {'jsonrpc': '2.0', 'id': message['id']}
    method = message.get('method')
    if method == 'initialize':
        result['result'] = {'protocolVersion': message.get('params', {}).get('protocolVersion', '2024-11-05'),
                            'capabilities': {'tools': {}},
                            'serverInfo': {'name': 'vael-pixellab', 'version': '1.0.0'}}
    elif method == 'ping':
        result['result'] = {}
    elif method in ('tools/list', 'tools/call'):
        upstream = pixellab.rpc(method, message.get('params', {}))
        for key in ('result', 'error'):
            if key in upstream:
                result[key] = upstream[key]
    else:
        result['error'] = {'code': -32601, 'message': 'Method not supported'}
    return result


def main() -> None:
    for line in sys.stdin:
        message = None
        try:
            message = json.loads(line)
            result = respond(message)
        except Exception as error:
            # Exception strings never contain the Authorization header or key.
            result = {'jsonrpc': '2.0', 'id': message.get('id') if isinstance(message, dict) else None,
                      'error': {'code': -32603, 'message': str(error)}}
        if result is not None:
            print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
