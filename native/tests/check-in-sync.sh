#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
testdir=$(mktemp -d /tmp/krest-check-in-sync.XXXXXX)
trap 'rm -rf "$testdir"' EXIT
cp tests/check-in-sync.swift "$testdir/main.swift"
sources=()
for file in swift/*.swift; do [ "$file" = swift/main.swift ] || sources+=("$file"); done
swiftc "${sources[@]}" "$testdir/main.swift" -o "$testdir/test" -framework AppKit
"$testdir/test"
