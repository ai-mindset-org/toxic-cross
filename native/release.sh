#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${SIGN_IDENTITY:?Set a Developer ID Application identity; this script never creates credentials}"
: "${NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
make bundle
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" build/Krest.app
codesign --verify --deep --strict build/Krest.app
mkdir -p dist
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
upload="dist/Krest-$version-notary-upload.zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent build/Krest.app "$upload"
xcrun notarytool submit "$upload" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple build/Krest.app
xcrun stapler validate build/Krest.app
spctl --assess --type execute --verbose build/Krest.app
artifact="dist/Krest-$version-$(uname -m).zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent build/Krest.app "$artifact"
shasum -a 256 "$artifact"
