#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 2 )); then
  print -u2 'Usage: scripts/finish-notarization.sh SUBMISSION_ID KEYCHAIN_PROFILE'
  exit 1
fi
cove_app="$PWD/dist/distribution/Cove.app"
cove_status=$(mktemp "$PWD/dist/distribution/.notary-status.XXXXXX")
trap 'rm -f "$cove_status"' EXIT
xcrun notarytool info "$1" --keychain-profile "$2" --output-format json > "$cove_status"
python3 - "$cove_status" <<'PY'
import json,sys
status=json.load(open(sys.argv[1]))['status']
print('Notarization status:',status)
if status!='Accepted': sys.exit('Not accepted yet. Inspect this submission; do not resubmit blindly.')
PY
xcrun stapler staple "$cove_app"
xcrun stapler validate "$cove_app"
codesign --verify --deep --strict "$cove_app"
spctl --assess --type execute --verbose=2 "$cove_app"
./scripts/build-dmg.sh
