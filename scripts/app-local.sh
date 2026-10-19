#!/bin/sh
set -eu

howmuch_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$(uname -s)" = Darwin ]; then
  howmuch_cache_root="$HOME/Library/Caches/how-much"
else
  howmuch_cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/how-much"
fi

export PUB_CACHE="${PUB_CACHE:-$howmuch_cache_root/pub}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$howmuch_cache_root/gradle}"
mkdir -p "$PUB_CACHE" "$GRADLE_USER_HOME"
cd "$howmuch_root/app"

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze --no-pub
flutter test --no-pub
