#!/bin/sh
# Builds macos/build/Pomodoro.app from the Swift package.
#
# Steps: swift build (release) → bundle layout → Info.plist with the version →
# icon from ../Assets/app-256.png → ../Sounds → strings JSON from ../Localization →
# codesign (ad-hoc by default).
#
# Env: VERSION (default: git describe --tags, else 0.0.0), CODESIGN_IDENTITY (default "-" = ad-hoc).
set -eu

cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
APP="build/Pomodoro.app"
CONTENTS="$APP/Contents"

VERSION="${VERSION:-}"
if [ -z "$VERSION" ]; then
    VERSION="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
fi
[ -n "$VERSION" ] || VERSION="0.0.0"
IDENTITY="${CODESIGN_IDENTITY:--}"

echo "==> swift build -c release"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/PomodoroApp"
[ -x "$BIN" ] || { echo "executable not found: $BIN" >&2; exit 1; }

echo "==> layout $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN" "$CONTENTS/MacOS/Pomodoro"

sed "s/__VERSION__/$VERSION/g" Info.plist > "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> icon"
sh scripts/icon.sh "$ROOT/Assets/app-256.png" "build/AppIcon.icns"
cp "build/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

echo "==> sounds"
mkdir -p "$CONTENTS/Resources/Sounds"
cp "$ROOT"/Sounds/*.wav "$CONTENTS/Resources/Sounds/"

echo "==> strings"
python3 scripts/strings.py "$ROOT/Localization" Localization "$CONTENTS/Resources/Localization"

echo "==> codesign ($IDENTITY)"
codesign --force --deep --sign "$IDENTITY" "$APP"

echo "==> $APP v$VERSION"
