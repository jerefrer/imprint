# CLAUDE.md — contexte projet

> Ce fichier est lu automatiquement par Claude Code à l'ouverture du dépôt.
> Il résume l'objectif, l'état actuel, les décisions prises et ce qui reste à faire.

## Objectif

**Imprint** — outil macOS **sans terminal** permettant à un utilisateur non
technique (Mathieu Ricard, photographe) d'appliquer les **légendes d'un fichier
Excel/CSV** aux **métadonnées de ses fichiers TIFF**, en remplacement d'une
procédure ExifTool en ligne de commande jugée trop compliquée.

Cible : MacBook Pro Apple Silicon (M2/M3), macOS Tahoe (26).

## Comportement attendu

1. L'utilisateur place dans **un même dossier** ses `.tif` + un fichier de
   légendes `.xlsx` ou `.csv` avec colonnes **`Filename`** et **`Description`**.
2. Double-clic sur `Imprint.app` → dialogue natif de choix du dossier.
3. L'app lit le tableau, associe chaque ligne au `.tif` du même nom
   (insensible à la casse, `MR10431.TIF` ↔ `MR10431.tif`) et écrit la légende
   (texte bilingue EN/FR gardé **tel quel**) dans :
   - `IPTC:Caption-Abstract`
   - `XMP-dc:Description`
   - `EXIF:ImageDescription`
4. Résumé affiché (légendées / lignes sans photo / photos sans légende).

## Architecture

```
app/Info.plist         # bundle .app (CFBundleName = Imprint, icône Imprint.icns)
app/run                # exécutable bash : UI via osascript, orchestration
app/parse_sheet.pl     # parseur xlsx/csv -> CSV compatible ExifTool (Perl cœur uniquement)
app/make_icns.sh       # génère app/Imprint.icns depuis Imprint.icon/Assets/*.jpg
app/Imprint.icns       # icône compilée (gitignorée, régénérée au build)
Imprint.icon/          # source de l'icône (format Icon Composer) – source de vérité
build_app.sh           # assemble app/ -> dist/.app, signe, notarise, produit DMG
dist/                  # artéfacts de build (gitignoré)
GUIDE-Mathieu.md       # notice pas-à-pas pour l'utilisateur final
README.md              # doc technique
```

- **Pas de binaire compilé** : l'exécutable du bundle est un script shell,
  lancé par `/bin/bash` (déjà signé Apple) → pas de problème de signature
  Mach-O sur Apple Silicon.
- **`parse_sheet.pl`** n'utilise que des modules du cœur de Perl
  (`IO::Uncompress::Unzip` pour décompresser le `.xlsx`). `/usr/bin/perl` suffit
  (présent sur macOS, vérifié encore présent sur Tahoe). Gère : séparateur `,`
  ou `;`, BOM UTF-8, guillemets, `""` échappés, **champs multilignes**.
- **ExifTool** : non bundlé. L'app le télécharge automatiquement au 1er lancement
  depuis exiftool.org (lit `ver.txt`, récupère le tarball) dans
  `~/Library/Application Support/Imprint/`. Cherche d'abord un ExifTool déjà
  installé (`/usr/local/bin`, `/opt/homebrew/bin`, PATH).
- Écriture forcée UTF-8 (`-codedcharacterset=utf8`), dates de fichier préservées
  (`-P`), originaux écrasés en place (`-overwrite_original`).
- La détection du tableau **ignore** les fichiers temporaires/verrous
  (`~$*.xlsx` d'Excel, `.~lock.*` de LibreOffice, fichiers cachés). Si un seul
  tableau reste, il est utilisé sans demander ; si plusieurs, un menu s'affiche.
- **Icône** : source dans `Imprint.icon/Assets/image-766264921340.jpg`
  (polaroid vintage + traits de plume, 1024×1024). `app/make_icns.sh` la
  convertit en `.icns` multi-résolution via `sips` + `iconutil`. Le format Icon
  Composer (`Imprint.icon/icon.json`) n'est pas utilisé en l'état : l'image est
  une icône finie, pas une couche pour le rendu Liquid Glass.

## Construire & signer

```bash
./build_app.sh --setup-credentials   # 1re fois : stocke le mdp d'app dans le trousseau
./build_app.sh                       # build + signe + notarise + agrafe -> DMG
```

Sortie : `dist/Imprint.dmg` — DMG signé + notarisé + agrafé, avec raccourci
« Applications » pour le glisser-déposer. C'est ce fichier qui est envoyé à
l'utilisateur final.

Options :

- `--no-notarize` : signe seulement, pas de round-trip Apple (rapide, hors-ligne).
- `--no-sign` : DMG brut, pour développement.
- Identité utilisée : `Developer ID Application: Jeremy Frere (3J4HCZ8V25)`,
  Team ID `3J4HCZ8V25`. Surchargeable via les vars `SIGN_IDENTITY`, `APPLE_ID`,
  `TEAM_ID`, `KEYCHAIN_PROFILE`.
- Le profil de notarisation est stocké dans le trousseau macOS sous le nom
  `imprint-notarize` (créé par `--setup-credentials` ; demande le mot de passe
  d'app spécifique généré sur appleid.apple.com).
- `CFBundleIdentifier` : `com.jeremyfrere.imprint`.

## État / ce qui a été vérifié

- ✅ Parseur testé sur les vrais fichiers (`Legendes_MR_Bhoutan_UTF8.xlsx` et
  `.csv`) : 23 légendes associées, 0 manquante, multilignes + accents OK,
  CSV de sortie relu sans erreur par le module `csv` de Python.
- ✅ Syntaxe bash validée (`bash -n`), filtrage des fichiers temporaires testé.
- ✅ Pipeline `codesign` + DMG fonctionnel en local (test 2026-05-29).
- ⚠️ **Notarisation jamais exécutée jusqu'au bout** : credentials non encore
  stockées. À faire via `./build_app.sh --setup-credentials` la première fois.
- ⚠️ **Étape ExifTool non exécutée** dans l'environnement de dev (pas d'accès
  réseau vers exiftool.org). À **tester une fois sur un vrai Mac** sur une copie
  d'un ou deux TIFF avant diffusion : vérifier que la légende apparaît bien dans
  le champ « Description » de Bridge/Photoshop et que les accents sont corrects.

## Gatekeeper / diffusion

- App **signée Developer ID + notarisée + agrafée** (depuis 2026-05-29).
  Plus d'avertissement Gatekeeper côté utilisateur : double-clic direct sur
  le DMG, glisser dans Applications, lancer.
- Diffusion : envoyer le `.dmg` (par mail, AirDrop, clé USB, lien…).

## TODO / pistes d'évolution

- [ ] Tester réellement l'écriture ExifTool sur un Mac (priorité).
- [ ] GUI native SwiftUI (drag-and-drop, progression, résumé checklist).
      Voir discussion dans la conversation 2026-05-29.
- [ ] Page GitHub Pages de présentation (univers polaroid vintage de l'icône).
- [ ] Mémoriser le dernier dossier utilisé (par ex. dans le dossier Support).
- [ ] Colonnes optionnelles supplémentaires : mots-clés (`IPTC:Keywords`),
      titre (`Headline`), auteur/copyright.
- [ ] Prise en charge d'autres formats (JPEG, DNG) si besoin.

## Notes de contexte

- Le dossier parent (`../`) contenait les TIFF de test + les fichiers de
  légendes d'origine (lot « Bhoutan »). Le dépôt Git ne suit que `legendes-tiff/`.
- Préférences de l'utilisateur (Jeremy) : réponses concises et directes.
