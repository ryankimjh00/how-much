#!/bin/sh
set -eu

howmuch_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$howmuch_root/scripts/app-local.sh" flutter pub get --enforce-lockfile
"$howmuch_root/scripts/app-local.sh" flutter build ios --debug --config-only --no-codesign --no-pub
"$howmuch_root/scripts/app-local.sh" pod install --project-directory=ios --deployment
"$howmuch_root/scripts/app-local.sh" xcodebuild -quiet \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-local \
  CODE_SIGNING_ALLOWED=NO build-for-testing
