#!/bin/bash
# Assemble l'application "Légender les photos.app" à partir des sources de app/,
# puis crée une archive .zip prête à être envoyée (permissions préservées).
#
# Usage :  ./build_app.sh
# Résultat : dist/Légender les photos.app  et  dist/Legender-les-photos.zip
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/app"
DIST="$HERE/dist"
APP="$DIST/Légender les photos.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$SRC/Info.plist"      "$APP/Contents/Info.plist"
cp "$SRC/run"             "$APP/Contents/MacOS/run"
cp "$SRC/parse_sheet.pl"  "$APP/Contents/Resources/parse_sheet.pl"
chmod +x "$APP/Contents/MacOS/run"

# Archive zip en préservant le bit exécutable
( cd "$DIST" && rm -f Legender-les-photos.zip && zip -r -X -y Legender-les-photos.zip "Légender les photos.app" >/dev/null )

echo "OK :"
echo "  $APP"
echo "  $DIST/Legender-les-photos.zip"
