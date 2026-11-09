#!/bin/sh
# Builds build/Pomodoro-<version>-macos.dmg from build/Pomodoro.app: a drag-to-Applications
# disk image with a drawn background (scripts/dmg-background.swift), the app on the left and
# an Applications link on the right. Finder is scripted to set the icon view, so the first run
# asks for permission to control Finder.
set -eu

cd "$(dirname "$0")/.."
APP="build/Pomodoro.app"
[ -d "$APP" ] || { echo "run 'make app' first" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VOLNAME="Pomodoro"
STAGING="build/dmg-staging"
RW="build/dmg-rw.dmg"
OUT="build/Pomodoro-$VERSION-macos.dmg"

echo "==> staging"
rm -rf "$STAGING" "$RW" "$OUT"
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
swift scripts/dmg-background.swift "$STAGING/.background/background.png"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGING/.VolumeIcon.icns"

echo "==> image"
# Detach a leftover volume from an earlier run, if any.
[ -d "/Volumes/$VOLNAME" ] && hdiutil detach "/Volumes/$VOLNAME" -quiet || true
hdiutil create -quiet -srcfolder "$STAGING" -volname "$VOLNAME" -fs HFS+ -format UDRW -ov "$RW"
DEV="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/\/Volumes\//{print $1; exit}')"
MOUNT="/Volumes/$VOLNAME"
# Custom volume icon flag (SetFile ships with the Command Line Tools; skip quietly if missing).
command -v SetFile >/dev/null && SetFile -a C "$MOUNT" || true

echo "==> Finder layout"
# Best effort: without a Finder session (CI) the image still works, just without the layout.
osascript <<EOF || echo "warning: Finder layout skipped"
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set text size of opts to 13
        set background picture of opts to file ".background:background.png"
        set position of item "Pomodoro.app" of container window to {165, 215}
        set position of item "Applications" of container window to {495, 215}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
sync

echo "==> compress"
hdiutil detach "$DEV" -quiet
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT"
rm -rf "$RW" "$STAGING"
echo "==> $OUT"
