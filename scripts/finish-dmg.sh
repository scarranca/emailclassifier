#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 3 )); then
  print -u2 'Usage: scripts/finish-dmg.sh DMG_PATH SUBMISSION_ID KEYCHAIN_PROFILE'
  exit 1
fi
cove_dmg="${1:A}"
[[ -f "$cove_dmg" && "$cove_dmg" == *.dmg ]] || exit 1
cove_status=$(mktemp "$PWD/dist/distribution/.dmg-status.XXXXXX")
trap 'rm -f "$cove_status"' EXIT
xcrun notarytool info "$2" --keychain-profile "$3" --output-format json > "$cove_status"
python3 - "$cove_status" <<'PY'
import json,sys
status=json.load(open(sys.argv[1]))['status']
print('Notarization status:', status)
if status != 'Accepted': sys.exit('Wait for this submission to be accepted; do not submit duplicates.')
PY
xcrun stapler staple "$cove_dmg"
xcrun stapler validate "$cove_dmg"
codesign --verify --strict "$cove_dmg"
hdiutil verify "$cove_dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$cove_dmg"
mkdir -p dist/releases
cove_release="$PWD/dist/releases/${cove_dmg:t}"
cp "$cove_dmg" "$cove_release"
shasum -a 256 "$cove_release" > "$cove_dmg.sha256"
print "Ready to share: $cove_release"
