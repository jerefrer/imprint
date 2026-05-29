# Légender les photos

Petit outil macOS, sans terminal, qui applique les légendes d'un fichier
**Excel (.xlsx)** ou **CSV** aux fichiers **TIFF** d'un dossier.

Conçu pour un usage non technique : l'utilisateur double-clique sur l'app,
choisit un dossier, et l'outil écrit la description de chaque photo dans ses
métadonnées (le champ « Légende / Description » lu par Adobe Bridge, Photoshop,
Lightroom et les agences photo).

## Comment ça marche

1. L'utilisateur range, dans **un même dossier**, ses photos `.tif` et un
   fichier de légendes (`.xlsx` ou `.csv`) avec deux colonnes : **`Filename`**
   et **`Description`**.
2. Double-clic sur **`Légender les photos.app`** → choix du dossier.
3. L'app lit le tableau, fait correspondre chaque ligne au fichier `.tif`
   du même nom (insensible à la casse, `IMG_001.TIF` ↔ `IMG_001.tif`), puis
   écrit la légende dans trois champs standard :
   - `IPTC:Caption-Abstract`
   - `XMP-dc:Description`
   - `EXIF:ImageDescription`
4. Un résumé s'affiche (photos légendées, lignes sans photo, photos sans légende).

Le moteur d'écriture des métadonnées est **ExifTool** (Phil Harvey). S'il n'est
pas déjà installé, l'app le télécharge automatiquement au premier lancement
(Internet requis cette fois-là uniquement) dans
`~/Library/Application Support/Legender les photos/`.

## Structure du dépôt

```
legendes-tiff/
├── app/
│   ├── Info.plist          # métadonnées du bundle .app
│   ├── run                 # exécutable (bash) : UI native + orchestration
│   └── parse_sheet.pl      # parseur xlsx/csv → CSV compatible ExifTool (Perl, modules cœur)
├── build_app.sh            # assemble app/ en "Légender les photos.app" + .zip
├── dist/                   # artéfacts de build (gitignoré)
└── GUIDE-l'utilisateur.md        # notice pas-à-pas en gros caractères pour l'utilisateur final
```

## Construire l'app

```bash
./build_app.sh
# → dist/Légender les photos.app
# → dist/Legender-les-photos.zip   (à envoyer ; le .zip préserve les permissions)
```

## Détails techniques

- **`parse_sheet.pl`** n'utilise que des modules du cœur de Perl
  (`IO::Uncompress::Unzip` pour décompresser le `.xlsx`), donc aucune
  installation Perl n'est nécessaire — `/usr/bin/perl` suffit (présent sur macOS).
  Il gère : séparateur `,` ou `;`, BOM UTF-8, champs entre guillemets,
  guillemets échappés (`""`) et **champs multilignes** (descriptions sur
  plusieurs lignes).
- **`run`** est l'exécutable du bundle : aucun binaire compilé, donc tout le
  code est lisible et modifiable. L'interface passe par `osascript`
  (dialogues natifs), il n'y a jamais de fenêtre Terminal.
- L'écriture IPTC est forcée en UTF-8 (`-codedcharacterset=utf8`) pour les
  accents ; les dates de fichier sont préservées (`-P`) ; les originaux sont
  écrasés en place (`-overwrite_original`).

### Signature / Gatekeeper

L'app **n'est pas signée ni notarisée**. Après un transfert (mail, AirDrop,
téléchargement), macOS lui attache l'attribut `com.apple.quarantine` et la
bloque au premier lancement.

Sur **macOS Sequoia (15) et Tahoe (26)**, le raccourci clic-droit → Ouvrir a été
supprimé. La première ouverture passe désormais par **Réglages Système →
Confidentialité et sécurité → « Ouvrir quand même »** (+ mot de passe admin),
une seule fois.

Contournements :
- **Clé USB / carte SD** : une copie depuis un volume externe via le Finder
  n'ajoute généralement pas la quarantaine → aucun avertissement.
- Retrait manuel de l'attribut : `xattr -dr com.apple.quarantine "Légender les photos.app"`.
- **Notarisation** (zéro friction, recommandé pour une diffusion régulière) :
  nécessite un compte Apple Developer, puis `codesign` + `notarytool` + `stapler`.

À noter : l'exécutable est un **script shell** (lancé par `/bin/bash`, déjà signé
par Apple), donc l'obligation de signature des binaires Mach-O sur Apple Silicon
ne s'applique pas ici — seul l'avertissement de quarantaine Gatekeeper subsiste.

> Tester localement sur la machine de build ne reproduit pas le blocage : la
> quarantaine n'est ajoutée qu'au moment du transfert.

## Reprendre avec Claude Code

Le dépôt est versionné avec Git. Pistes d'évolution possibles :
- icône d'application personnalisée ;
- signature + notarisation Apple (supprime l'avertissement Gatekeeper) ;
- colonnes supplémentaires (mots-clés `IPTC:Keywords`, titre `Headline`, auteur…) ;
- mémoriser le dernier dossier utilisé ;
- prise en charge d'autres formats d'image (JPEG, DNG…).
