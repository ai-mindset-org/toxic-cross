#!/usr/bin/env python3
"""Run production server + native URLSession against disposable loopback-only data."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

native = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="krest-http-") as folder:
    root = Path(folder).resolve()
    os.environ["KREST_ROOT"] = str(root)
    # Import the current canonical API with its root resolved before any request.
    sys.path.insert(0, str(native.parent))
    spec = importlib.util.spec_from_file_location("krest_isolated_http", native.parent / "server.py")
    server = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(server)
    assert server.КОРЕНЬ == root and server.ИСТОЧНИКИ == root / "источники"
    with server.Сервер(("127.0.0.1", 0), server.Рук) as http:
        worker = threading.Thread(target=http.serve_forever, daemon=True)
        worker.start()
        try:
            result = subprocess.run([sys.argv[1], f"http://127.0.0.1:{http.server_address[1]}", str(root)], timeout=60)
            if result.returncode:
                raise SystemExit(result.returncode)
            # Prove API persistence used the disposable journal and excluded title/URL fields.
            journal = root / "источники" / "check-ins.local.json"
            assert journal.exists() and journal.stat().st_mode & 0o777 == 0o600
            assert "EXCLUDED FIXTURE TITLE" not in journal.read_text()
        finally:
            http.shutdown()
            worker.join(timeout=5)
