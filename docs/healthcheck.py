#!/usr/bin/env python3
"""Report loopback/optional private HTTPS health. No restart, route change or scheduler."""
import os
import urllib.request
import urllib.parse


def check(label, url):
    try:
        request = urllib.request.Request(url, method='GET')
        with urllib.request.urlopen(request, timeout=5) as response:
            ok = response.status == 200
        print(label + (' 200' if ok else ' failed')); return ok
    except Exception:
        print(label + ' failed'); return False


if __name__ == '__main__':
    local = 'http://127.0.0.1:' + str(int(os.environ.get('KREST_PORT', '8777'))) + '/'
    ok = check('local', local)
    remote = os.environ.get('KREST_PRIVATE_URL')
    if remote:
        parts = urllib.parse.urlsplit(remote)
        if parts.scheme != 'https' or not parts.hostname or parts.username or parts.password:
            raise SystemExit('Private remote health URL must be HTTPS without embedded credentials')
        ok = check('private remote', remote) and ok
    raise SystemExit(0 if ok else 1)
