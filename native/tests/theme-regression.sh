#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
testdir=$(mktemp -d /tmp/krest-theme-test.XXXXXX)
trap 'rm -rf "$testdir"' EXIT
cp tests/theme-regression.swift "$testdir/main.swift"
sources=()
for file in swift/*.swift; do [ "$file" = swift/main.swift ] || sources+=("$file"); done
swiftc "${sources[@]}" "$testdir/main.swift" -o "$testdir/test" -framework AppKit
"$testdir/test"
