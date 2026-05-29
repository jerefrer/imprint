#!/bin/bash
# Génère app/Imprint.icns à partir du fichier source PNG/JPG 1024x1024.
# Usage : ./app/make_icns.sh path/to/source-1024x1024.png
set -euo pipefail
SRC="${1:-Imprint.icon/Assets/image-766264921340.jpg}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT_ICNS="$HERE/Imprint.icns"

[ -f "$SRC" ] || { echo "Source introuvable : $SRC" >&2; exit 1; }

WORK="$(/usr/bin/mktemp -d /tmp/imprint-icns.XXXXXX)"
SET="$WORK/Imprint.iconset"
mkdir -p "$SET"

PNG="$WORK/source.png"
/usr/bin/sips -s format png "$SRC" --out "$PNG" >/dev/null

emit() { /usr/bin/sips -z "$1" "$1" "$PNG" --out "$SET/$2" >/dev/null; }
emit 16   icon_16x16.png
emit 32   icon_16x16@2x.png
emit 32   icon_32x32.png
emit 64   icon_32x32@2x.png
emit 128  icon_128x128.png
emit 256  icon_128x128@2x.png
emit 256  icon_256x256.png
emit 512  icon_256x256@2x.png
emit 512  icon_512x512.png
emit 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$SET" -o "$OUT_ICNS"
rm -rf "$WORK"

echo "OK : $OUT_ICNS ($(/usr/bin/stat -f%z "$OUT_ICNS") octets)"
