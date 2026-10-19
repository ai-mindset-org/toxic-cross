#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
testdir=$(mktemp -d /tmp/krest-http-build.XXXXXX)
trap 'rm -rf "$testdir"' EXIT
cp tests/check-in-http.swift "$testdir/main.swift"
sources=()
for file in swift/*.swift; do [ "$file" = swift/main.swift ] || sources+=("$file"); done
swiftc "${sources[@]}" "$testdir/main.swift" -o "$testdir/test" -framework AppKit
PYTHONDONTWRITEBYTECODE=1 python3 tests/check-in-http.py "$testdir/test"
