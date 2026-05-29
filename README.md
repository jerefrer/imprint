# Imprint

Petit outil macOS, sans terminal, qui applique les légendes d'un fichier
**Excel (.xlsx)** ou **CSV** aux fichiers **TIFF** d'un dossier.

Conçu pour un usage non technique : l'utilisateur double-clique sur l'app,
choisit un dossier, et Imprint écrit la description de chaque photo dans ses
métadonnées (le champ « Légende / Description » lu par Adobe Bridge, Photoshop,
Lightroom et les agences photo).

## Comment ça marche

1. L'utilisateur range, dans **un même dossier**, ses photos `.tif` et un
   fichier de légendes (`.xlsx` ou `.csv`) avec deux colonnes : **`Filename`**
   et **`Description`**.
2. Double-clic sur **`Imprint.app`** → choix du dossier.
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
`~/Library/Application Support/Imprint/`.

## Structure du dépôt

```
legendes-tiff/
├── app/
│   ├── Info.plist          # métadonnées du bundle .app
│   ├── run                 # exécutable (bash) : UI native + orchestration
│   ├── parse_sheet.pl      # parseur xlsx/csv → CSV compatible ExifTool (Perl, modules cœur)
│   ├── make_icns.sh        # génère Imprint.icns depuis la source de l'icône
│   └── Imprint.icns        # icône compilée (gitignorée, régénérée au build)
├── Imprint.icon/           # source de l'icône (format Icon Composer / image 1024×1024)
├── build_app.sh            # assemble app/, signe, notarise, produit le DMG
├── dist/                   # artéfacts de build (gitignoré)
└── GUIDE-l'utilisateur.md        # notice pas-à-pas en gros caractères pour l'utilisateur final
```

## Construire & signer

Première fois seulement — stocke le mot de passe d'app spécifique dans le trousseau :

```bash
./build_app.sh --setup-credentials
```
(Mot de passe à générer sur https://appleid.apple.com → *Connexion et sécurité* → *Mots de passe pour apps*.)

Ensuite, à chaque release :

```bash
./build_app.sh
# → dist/Imprint.app
# → dist/Imprint.dmg   ← l'unique fichier à envoyer
```

Le DMG est signé Developer ID, notarisé par Apple, et le ticket est agrafé :
l'utilisateur final n'a aucun avertissement Gatekeeper. Il l'ouvre, glisse
l'app dans Applications, c'est tout.

Options utiles :
- `--no-notarize` : signe seulement (rapide, hors-ligne, pour test).
- `--no-sign` : DMG brut, non signé (développement uniquement).

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
- **Icône** : source dans `Imprint.icon/Assets/image-766264921340.jpg`
  (polaroid vintage sur papier crème + traits de plume, 1024×1024). Compilée
  en `.icns` multi-résolution par `app/make_icns.sh` (sips + iconutil).

## Reprendre avec Claude Code

Le dépôt est versionné avec Git. Pistes d'évolution possibles :
- GUI native SwiftUI (drag-and-drop, progression, résumé) ;
- page GitHub Pages de présentation ;
- colonnes supplémentaires (mots-clés `IPTC:Keywords`, titre `Headline`, auteur…) ;
- mémoriser le dernier dossier utilisé ;
- prise en charge d'autres formats d'image (JPEG, DNG…).
