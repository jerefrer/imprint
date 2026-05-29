# CLAUDE.md — contexte projet

> Ce fichier est lu automatiquement par Claude Code à l'ouverture du dépôt.
> Il résume l'objectif, l'état actuel, les décisions prises et ce qui reste à faire.

## Objectif

Outil macOS **sans terminal** permettant à un utilisateur non technique
(Mathieu Ricard, photographe) d'appliquer les **légendes d'un fichier Excel/CSV**
aux **métadonnées de ses fichiers TIFF**, en remplacement d'une procédure
ExifTool en ligne de commande jugée trop compliquée.

Cible : MacBook Pro Apple Silicon (M2/M3), macOS Tahoe (26).

## Comportement attendu

1. L'utilisateur place dans **un même dossier** ses `.tif` + un fichier de
   légendes `.xlsx` ou `.csv` avec colonnes **`Filename`** et **`Description`**.
2. Double-clic sur `Légender les photos.app` → dialogue natif de choix du dossier.
3. L'app lit le tableau, associe chaque ligne au `.tif` du même nom
   (insensible à la casse, `MR10431.TIF` ↔ `MR10431.tif`) et écrit la légende
   (texte bilingue EN/FR gardé **tel quel**) dans :
   - `IPTC:Caption-Abstract`
   - `XMP-dc:Description`
   - `EXIF:ImageDescription`
4. Résumé affiché (légendées / lignes sans photo / photos sans légende).

## Architecture

```
app/Info.plist         # bundle .app (CFBundleExecutable = run)
app/run                # exécutable bash : UI via osascript, orchestration
app/parse_sheet.pl     # parseur xlsx/csv -> CSV compatible ExifTool (Perl cœur uniquement)
build_app.sh           # assemble app/ -> "dist/Légender les photos.app" + .zip
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
  `~/Library/Application Support/Legender les photos/`. Cherche d'abord un
  ExifTool déjà installé (`/usr/local/bin`, `/opt/homebrew/bin`, PATH).
- Écriture forcée UTF-8 (`-codedcharacterset=utf8`), dates de fichier préservées
  (`-P`), originaux écrasés en place (`-overwrite_original`).
- La détection du tableau **ignore** les fichiers temporaires/verrous
  (`~$*.xlsx` d'Excel, `.~lock.*` de LibreOffice, fichiers cachés). Si un seul
  tableau reste, il est utilisé sans demander ; si plusieurs, un menu s'affiche.

## Construire

```bash
./build_app.sh   # -> dist/Légender les photos.app  et  dist/Legender-les-photos.zip
```
Le `.zip` (et non l'app nue) doit être envoyé : il préserve le bit exécutable.

## État / ce qui a été vérifié

- ✅ Parseur testé sur les vrais fichiers (`Legendes_MR_Bhoutan_UTF8.xlsx` et
  `.csv`) : 23 légendes associées, 0 manquante, multilignes + accents OK,
  CSV de sortie relu sans erreur par le module `csv` de Python.
- ✅ Syntaxe bash validée (`bash -n`), filtrage des fichiers temporaires testé.
- ⚠️ **Étape ExifTool non exécutée** dans l'environnement de dev (pas d'accès
  réseau vers exiftool.org). À **tester une fois sur un vrai Mac** sur une copie
  d'un ou deux TIFF avant diffusion : vérifier que la légende apparaît bien dans
  le champ « Description » de Bridge/Photoshop et que les accents sont corrects.

## Gatekeeper / diffusion

- App **non signée, non notarisée**. Après transfert, macOS la met en quarantaine.
- Sur **Sequoia/Tahoe**, le clic-droit → Ouvrir n'existe plus : 1re ouverture via
  **Réglages Système → Confidentialité et sécurité → « Ouvrir quand même »**.
- Contournement simple pour l'utilisateur final : transfert par **clé USB**
  (le Finder n'ajoute pas la quarantaine depuis un volume externe).

## TODO / pistes d'évolution

- [ ] Tester réellement l'écriture ExifTool sur un Mac (priorité).
- [ ] Notarisation Apple (`codesign` + `notarytool` + `stapler`) pour supprimer
      l'avertissement Gatekeeper — nécessite un compte Apple Developer.
- [ ] Icône d'application personnalisée.
- [ ] Mémoriser le dernier dossier utilisé (par ex. dans le dossier Support).
- [ ] Colonnes optionnelles supplémentaires : mots-clés (`IPTC:Keywords`),
      titre (`Headline`), auteur/copyright.
- [ ] Prise en charge d'autres formats (JPEG, DNG) si besoin.

## Notes de contexte

- Le dossier parent (`../`) contenait les TIFF de test + les fichiers de
  légendes d'origine (lot « Bhoutan »). Le dépôt Git ne suit que `legendes-tiff/`.
- Préférences de l'utilisateur (Jeremy) : réponses concises et directes.
