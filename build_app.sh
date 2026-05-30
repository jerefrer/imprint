#!/bin/bash
# =============================================================================
#  build_app.sh — assemble + signe + notarise Imprint.app
#                 et produit un DMG « glisser dans Applications »
#
#  Usage :
#    ./build_app.sh                  # build + signe + notarise + agrafe + DMG
#    ./build_app.sh --no-notarize    # build + signe + DMG (rapide, hors-ligne)
#    ./build_app.sh --no-sign        # build + DMG seulement (dev, app brute)
#    ./build_app.sh --setup-credentials
#                                    # à exécuter UNE SEULE FOIS pour stocker
#                                    # le mot de passe d'app dans le trousseau
#
#  Variables d'environnement (surcharge les valeurs par défaut) :
#    SIGN_IDENTITY      "Developer ID Application: Jeremy Frere (3J4HCZ8V25)"
#    KEYCHAIN_PROFILE   "imprint-notarize"
#    APPLE_ID           "frere.jeremy@gmail.com"
#    TEAM_ID            "3J4HCZ8V25"
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/app"
DIST="$HERE/dist"
APP_NAME="Imprint"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/Imprint.dmg"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Jeremy Frere (3J4HCZ8V25)}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-imprint-notarize}"
APPLE_ID="${APPLE_ID:-frere.jeremy@gmail.com}"
TEAM_ID="${TEAM_ID:-3J4HCZ8V25}"

DO_SIGN=1
DO_NOTARIZE=1
SETUP_CREDS=0

usage() {
    sed -n '2,22p' "$0"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --no-sign)                   DO_SIGN=0; DO_NOTARIZE=0 ;;
        --no-notarize)               DO_NOTARIZE=0 ;;
        --setup-credentials|--setup) SETUP_CREDS=1 ;;
        -h|--help)                   usage; exit 0 ;;
        *) echo "Option inconnue : $1" >&2; usage; exit 2 ;;
    esac
    shift
done

# --- Setup credentials (à faire une seule fois) ------------------------------
if [ "$SETUP_CREDS" -eq 1 ]; then
    cat <<EOF
Configuration du profil de notarisation dans le trousseau macOS.

Il vous faut un MOT DE PASSE D'APP SPÉCIFIQUE (≠ mot de passe iCloud).
Si vous n'en avez pas encore :
  1. Ouvrez https://appleid.apple.com
  2. Section « Connexion et sécurité » → « Mots de passe pour apps »
  3. Créez-en un (libellé p. ex. « notarytool legender »)
     → format affiché : xxxx-xxxx-xxxx-xxxx

Vous serez invité à le coller ci-dessous.

  Apple ID :  $APPLE_ID
  Team ID  :  $TEAM_ID
  Profil   :  $KEYCHAIN_PROFILE

EOF
    xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" \
        --apple-id "$APPLE_ID" \
        --team-id  "$TEAM_ID"
    echo
    echo "✅ Profil stocké. Vous pouvez maintenant relancer ./build_app.sh sans option."
    exit 0
fi

mkdir -p "$DIST"

# --- 1. Compilation Swift ----------------------------------------------------
echo "→ Compilation de l'app Swift (release)"
(
    cd "$HERE"
    swift build -c release --arch arm64 2>&1 | sed 's/^/   /'
)
BIN="$HERE/.build/arm64-apple-macosx/release/Imprint"
[ -x "$BIN" ] || { echo "❌ Binaire Imprint introuvable après compilation : $BIN" >&2; exit 5; }

# --- 2. Assemblage du bundle .app -------------------------------------------
echo "→ Assemblage du bundle .app"
# Régénère l'icône .icns si elle manque OU si la source a été modifiée depuis
ICNS="$SRC/Imprint.icns"
ICON_SRC="$HERE/Imprint.icon/Assets/image-766264921340.jpg"
if [ ! -f "$ICNS" ] || { [ -f "$ICON_SRC" ] && [ "$ICON_SRC" -nt "$ICNS" ]; }; then
    echo "  (régénération de Imprint.icns depuis la source)"
    "$SRC/make_icns.sh"
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$SRC/Info.plist"      "$APP/Contents/Info.plist"
cp "$BIN"                 "$APP/Contents/MacOS/Imprint"
cp "$SRC/parse_sheet.pl"  "$APP/Contents/Resources/parse_sheet.pl"
cp "$SRC/Imprint.icns"    "$APP/Contents/Resources/Imprint.icns"
chmod +x "$APP/Contents/MacOS/Imprint"

# Sparkle.framework (auto-updater) doit être embarqué dans Contents/Frameworks/
SPARKLE_FW_SRC="$HERE/.build/arm64-apple-macosx/release/Sparkle.framework"
if [ ! -d "$SPARKLE_FW_SRC" ]; then
    echo "❌ Sparkle.framework introuvable : $SPARKLE_FW_SRC" >&2
    echo "   Le build SwiftPM aurait dû la produire. Relancez ./build_app.sh." >&2
    exit 6
fi
cp -R "$SPARKLE_FW_SRC" "$APP/Contents/Frameworks/"

# Le binaire est linké contre @rpath/Sparkle.framework/... — il faut donc lui
# ajouter @executable_path/../Frameworks dans ses rpaths. install_name_tool
# retourne != 0 si l'entrée existe déjà (rebuild incrémental) ; on l'ignore.
install_name_tool -add_rpath @executable_path/../Frameworks \
    "$APP/Contents/MacOS/Imprint" 2>/dev/null || true

# --- 3. Signature de l'app (hardened runtime, requis pour notarisation) -----
if [ "$DO_SIGN" -eq 1 ]; then
    if ! security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
        echo "❌ Identité de signature introuvable dans le trousseau :" >&2
        echo "   $SIGN_IDENTITY" >&2
        echo "Identités disponibles :" >&2
        security find-identity -v -p codesigning >&2
        exit 3
    fi
    echo "→ Signature de l'app + Sparkle (hardened runtime + horodatage)"
    SPARKLE_FW="$APP/Contents/Frameworks/Sparkle.framework"
    # Bottom-up : XPC services, Autoupdate binary, framework, puis l'app.
    # L'ordre est critique : codesign d'un conteneur ne valide pas son
    # contenu, il faut donc signer du plus profond au plus extérieur.
    for inner in \
        "$SPARKLE_FW/Versions/B/XPCServices/Downloader.xpc" \
        "$SPARKLE_FW/Versions/B/XPCServices/Installer.xpc" \
        "$SPARKLE_FW/Versions/B/Autoupdate" \
        "$SPARKLE_FW"; do
        codesign --force --options runtime --timestamp \
                 --sign "$SIGN_IDENTITY" \
                 "$inner"
    done
    codesign --force --options runtime --timestamp \
             --sign "$SIGN_IDENTITY" \
             "$APP"
    codesign --verify --strict --verbose=2 "$APP" 2>&1 | sed 's/^/   /'
fi

# --- 4. Construction du DMG (glisser-déposer dans Applications) -------------
echo "→ Construction du DMG"
# Nettoyage d'éventuels artefacts précédents
STAGE="$(/usr/bin/mktemp -d /tmp/imprint-dmg.XXXXXX)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
/usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" >/dev/null
rm -rf "$STAGE"

# --- 5. Signature du DMG (recommandé) ---------------------------------------
if [ "$DO_SIGN" -eq 1 ]; then
    echo "→ Signature du DMG"
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
    codesign --verify --verbose=2 "$DMG" 2>&1 | sed 's/^/   /'
fi

# --- 6. Notarisation + agrafage sur le DMG ----------------------------------
if [ "$DO_NOTARIZE" -eq 1 ]; then
    if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
        cat >&2 <<EOF
❌ Profil de notarisation « $KEYCHAIN_PROFILE » introuvable.

Lancez d'abord, une seule fois :
   ./build_app.sh --setup-credentials

Ou bien, pour signer sans notariser :
   ./build_app.sh --no-notarize
EOF
        exit 4
    fi

    echo "→ Envoi du DMG à Apple pour notarisation (≈ 1 à 5 min)…"
    xcrun notarytool submit "$DMG" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait \
        --verbose

    echo "→ Agrafage du ticket de notarisation sur le DMG"
    xcrun stapler staple "$DMG"

    echo "→ Validation finale Gatekeeper"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" 2>&1 | sed 's/^/   /' || true
fi

# --- 7. Résumé ---------------------------------------------------------------
echo
echo "OK :"
echo "  $APP"
echo "  $DMG"
if [ "$DO_NOTARIZE" -eq 1 ]; then
    echo "  → DMG signé + notarisé + agrafé : aucun avertissement Gatekeeper."
elif [ "$DO_SIGN" -eq 1 ]; then
    echo "  → Signé mais non notarisé : Gatekeeper avertit toujours."
else
    echo "  → Non signé : Gatekeeper bloque au premier lancement."
fi
