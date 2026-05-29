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
Package.swift                  # manifeste SwiftPM (cible macOS 14)
Sources/Imprint/
  ImprintApp.swift             # @main, fenêtre
  ContentView.swift            # racine, switch sur AppState
  DropZoneView.swift           # zone drag-drop + NSOpenPanel
  ProcessingView.swift         # progression (déterminée ou indéterminée)
  SummaryView.swift            # résumé + liste de fichiers avec checkmarks
  ErrorView.swift              # état d'erreur
  ImprintEngine.swift          # orchestration : trouve sheet, lance parse_sheet.pl,
                               # installe ExifTool, lance exiftool en streaming
  Models.swift                 # AppState, ProcessSummary, FileResult, ImprintError
  Theme.swift                  # palette crème/sépia tirée de l'icône
app/Info.plist                 # bundle .app (CFBundleExecutable = Imprint, icône Imprint.icns)
app/parse_sheet.pl             # parseur xlsx/csv -> CSV compatible ExifTool (Perl cœur uniquement)
app/make_icns.sh               # génère app/Imprint.icns depuis Imprint.icon/Assets/*.jpg
app/Imprint.icns               # icône compilée (gitignorée, régénérée au build)
Imprint.icon/                  # source de l'icône (image 1024×1024 + icon.json Icon Composer)
build_app.sh                   # swift build + assemblage bundle + sign + DMG + notarise
dist/                          # artéfacts de build (gitignoré)
.build/                        # cache SwiftPM (gitignoré)
README.md                      # README utilisateur (sexy, simple)
```

- **Architecture** : SwiftUI natif pour l'UI (drag-drop, progression, résumé).
  Le binaire Mach-O appelle `parse_sheet.pl` (Perl) et `exiftool` (Perl aussi)
  comme child processes via `Process`. ExifTool streame son `-progress` sur
  stdout, `ImprintEngine` parse les lignes `========` pour mettre à jour la
  progression en temps réel.
- **`parse_sheet.pl`** n'utilise que des modules du cœur de Perl
  (`IO::Uncompress::Unzip` pour décompresser le `.xlsx`). `/usr/bin/perl` suffit
  (présent sur macOS, vérifié encore présent sur Tahoe). Gère : séparateur `,`
  ou `;`, BOM UTF-8, guillemets, `""` échappés, **champs multilignes**.
  Sortie : CSV stdout pour exiftool ; stderr avec `ASSOCIES=N`, `NON_TROUVES=N`,
  `TIF_SANS_LEGENDE=N` et la liste de chaque fichier sous chaque section.
- **ExifTool** : non bundlé. `ImprintEngine.ensureExifTool()` cherche
  `/usr/local/bin/exiftool`, `/opt/homebrew/bin/exiftool`, puis le PATH,
  puis `~/Library/Application Support/Imprint/Image-ExifTool-VERSION/`,
  puis télécharge depuis exiftool.org (URLSession + tar).
- Écriture forcée UTF-8 (`-codedcharacterset=utf8`), dates de fichier préservées
  (`-P`), originaux écrasés en place (`-overwrite_original`).
- La détection du tableau (dans `ImprintEngine.findSheet`) **ignore** les
  fichiers temporaires/verrous (`~$*.xlsx`, `.~lock.*`, fichiers cachés). Si
  plusieurs candidats, préfère le `.xlsx` ; sinon lève `ImprintError.multipleSheets`.
- **Icône** : source dans `Imprint.icon/Assets/image-766264921340.jpg`
  (polaroid vintage + traits de plume, 1024×1024). `app/make_icns.sh` la
  convertit en `.icns` multi-résolution via `sips` + `iconutil`. Le format Icon
  Composer (`Imprint.icon/icon.json`) n'est pas utilisé en l'état : l'image est
  une icône finie, pas une couche pour le rendu Liquid Glass.
- **Concurrence Swift 6** : l'état mutable partagé entre les readability
  handlers d'ExifTool est encapsulé dans une classe `ExifToolRunState`
  (`@unchecked Sendable`) pour éviter les captures mutables interdites en
  strict concurrency mode.

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
  `.csv`) : 23 légendes associées, 0 manquante, multilignes + accents OK.
- ✅ Pipeline `codesign` + DMG + notarisation Apple end-to-end (2026-05-29).
- ✅ Écriture ExifTool sur de vrais TIFF, validée par Mathieu (Bridge/Photoshop
  affichent correctement la « Description », accents OK).
- ✅ Compilation SwiftUI release, 540 Ko de binaire, aucun warning.
- ⚠️ **Mode strict Swift 6** : non testé. Les captures mutables ont été
  encapsulées dans `ExifToolRunState` mais le projet compile en mode Swift 5
  (warnings traités).

## Gatekeeper / diffusion

- App **signée Developer ID + notarisée + agrafée** (depuis 2026-05-29).
  Plus d'avertissement Gatekeeper côté utilisateur : double-clic direct sur
  le DMG, glisser dans Applications, lancer.
- Diffusion : envoyer le `.dmg` (par mail, AirDrop, clé USB, lien…).

## TODO / pistes d'évolution

- [x] GUI native SwiftUI (drag-and-drop, progression, résumé checklist) — fait
      sur la branche feature/swiftui-ui le 2026-05-29.
- [ ] Screenshots de l'app pour le README et la future page GitHub Pages.
- [ ] Page GitHub Pages de présentation (univers polaroid vintage de l'icône).
- [ ] Universal binary (arm64 + x86_64) pour les Macs Intel restants.
- [ ] Mémoriser le dernier dossier utilisé (par ex. dans le dossier Support).
- [ ] Colonnes optionnelles supplémentaires : mots-clés (`IPTC:Keywords`),
      titre (`Headline`), auteur/copyright.
- [ ] Prise en charge d'autres formats (JPEG, DNG) si besoin.

## Notes de contexte

- Le dossier parent (`../`) contenait les TIFF de test + les fichiers de
  légendes d'origine (lot « Bhoutan »). Le dépôt Git ne suit que `legendes-tiff/`.
- Préférences de l'utilisateur (Jeremy) : réponses concises et directes.
