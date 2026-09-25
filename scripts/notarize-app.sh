#!/bin/zsh
# Submit once. Keep the returned submission ID instead of retrying an uncertain submission.
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 1 )); then
  print -u2 'Usage: scripts/notarize-app.sh KEYCHAIN_PROFILE'
  exit 1
fi
cove_app="$PWD/dist/distribution/Cove.app"
cove_archive="$PWD/dist/distribution/Cove-notarization.zip"
codesign --verify --deep --strict "$cove_app"
codesign -dvv "$cove_app" 2>&1 | rg '^Authority=Developer ID Application:'
cove_archs=$(lipo -archs "$cove_app/Contents/MacOS/Cove")
[[ "$cove_archs" == 'x86_64 arm64' || "$cove_archs" == 'arm64 x86_64' ]] || {
  print -u2 "Expected both Mac architectures; found: $cove_archs"
  exit 1
}
# Recreate the upload from the current signed bundle, never a potentially stale archive.
ditto -c -k --keepParent "$cove_app" "$cove_archive"
cove_submission_dir=$(mktemp -d "$PWD/dist/distribution/notary.XXXXXX")
print "Submission receipt: $cove_submission_dir/submission.json"
xcrun notarytool submit "$cove_archive" --keychain-profile "$1" --output-format json --no-wait > "$cove_submission_dir/submission.json"
python3 - "$cove_submission_dir/submission.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
print('Submission ID:',r['id'])
print('Check this ID with notarytool info. Do not submit again while it is processing.')
PY
