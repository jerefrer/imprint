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
   du même nom (insensible à la casse, `MR10431.TIF` ↔ `MR10431.tif`), puis
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
└── GUIDE-Mathieu.md        # notice pas-à-pas en gros caractères pour l'utilisateur final
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

### Première ouverture sur le Mac de l'utilisateur

L'app n'est pas signée par un développeur identifié Apple. Au tout premier
lancement, macOS affiche un avertissement. Solution : **clic droit sur l'app →
Ouvrir → Ouvrir**. Une seule fois ; ensuite le double-clic fonctionne normalement.

## Reprendre avec Claude Code

Le dépôt est versionné avec Git. Pistes d'évolution possibles :
- icône d'application personnalisée ;
- signature + notarisation Apple (supprime l'avertissement Gatekeeper) ;
- colonnes supplémentaires (mots-clés `IPTC:Keywords`, titre `Headline`, auteur…) ;
- mémoriser le dernier dossier utilisé ;
- prise en charge d'autres formats d'image (JPEG, DNG…).
