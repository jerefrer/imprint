#!/usr/bin/perl
# parse_sheet.pl <dossier> <fichier.xlsx|.csv>
# Lit un tableau (Excel .xlsx ou CSV ; ou ,) avec colonnes "Filename" et "Description",
# associe chaque ligne au vrai fichier .tif present dans <dossier> (insensible a la casse),
# et ecrit sur la sortie standard un CSV compatible exiftool :
#   SourceFile,EXIF:ImageDescription,IPTC:Caption-Abstract,XMP-dc:Description
# Diagnostics (associes / non trouves / sans legende) sur STDERR.
# N'utilise que des modules du coeur de Perl (aucune installation requise).

use strict;
use warnings;

my ($dir, $file) = @ARGV;
die "usage: parse_sheet.pl <dossier> <fichier>\n" unless defined $dir && defined $file;
die "dossier introuvable: $dir\n" unless -d $dir;
die "fichier introuvable: $file\n" unless -f $file;

# ---------- 1. Lire le tableau en une liste de lignes (chaque ligne = [cellules]) ----------
my @rows;
if ($file =~ /\.xlsx$/i) {
    @rows = read_xlsx($file);
} else {
    my $text = read_file_raw($file);
    @rows = parse_csv($text);
}

# ---------- 2. Trouver les colonnes Filename / Description(s) ----------
# Headers reconnus (insensible a la casse, espaces et parentheses tolerees) :
#   filename
#   description                       — colonne unique, langue unique
#   description (xx) / description xx — code langue 2-5 lettres : FR, EN, ES,
#                                       DE, IT, PT, ZH, JA, ZH-CN, EN-US…
#   desc (xx) / legende (xx) / caption (xx) — variantes synonymes acceptees
#   xx                                — code langue seul (FR, EN, ES…)
# Si plusieurs colonnes de langue sont presentes, elles sont joinées dans
# l'ordre des colonnes (gauche → droite) avec « / » comme separateur, pour
# que l'app fonctionne aussi pour des photographes hispanophones, germanophones, etc.
my ($fcol, $dcol_single, $header_idx) = (-1, -1, -1);
my @dcols = ();  # liste des indices de colonnes de description par langue, ordre gauche→droite
for my $i (0 .. $#rows) {
    my @c = @{$rows[$i]};
    my @local_dcols;
    my $local_dcol_single = -1;
    for my $j (0 .. $#c) {
        my $v = defined $c[$j] ? lc trim($c[$j]) : '';
        $v =~ s/[()]//g; $v =~ s/\s+/ /g;
        $fcol = $j if $v eq 'filename';
        # « description » seule
        if ($v eq 'description' || $v eq 'legende' || $v eq 'caption') {
            $local_dcol_single = $j;
        }
        # « description xx » où xx est un code langue
        elsif ($v =~ /^(?:description|desc|legende|caption)\s+([a-z]{2}(?:-[a-z]{2})?)$/) {
            push @local_dcols, $j;
        }
        # « xx » seul (juste un code langue)
        elsif ($v =~ /^[a-z]{2}(?:-[a-z]{2})?$/) {
            push @local_dcols, $j;
        }
    }
    if ($fcol >= 0) {
        $header_idx = $i;
        @dcols = @local_dcols;
        $dcol_single = $local_dcol_single;
        last;
    }
}
# Si on a des colonnes de langue explicites, on les utilise. Sinon, la colonne
# « Description » simple. Sinon repli sur la colonne 1 (col 0 = filename).
if ($fcol < 0) { $fcol = 0; $dcol_single = 1; $header_idx = -1; }
if (!@dcols && $dcol_single < 0) { $dcol_single = $fcol + 1; }

# ---------- 3. Lister les vrais fichiers .tif du dossier (map insensible a la casse) ----------
opendir(my $dh, $dir) or die "lecture dossier impossible: $!\n";
my @disk = grep { /\.tiff?$/i && -f "$dir/$_" } readdir($dh);
closedir($dh);
my %by_key;            # cle normalisee -> vrai nom de fichier
for my $name (@disk) {
    $by_key{ norm_key($name) } = $name;   # cle complete (avec extension)
    (my $base = $name) =~ s/\.[^.]+$//;
    $by_key{ "base:" . lc($base) } //= $name;  # cle sans extension (repli)
}

# ---------- 4. Construire les lignes de sortie ----------
my @out;
my @unmatched;
my %used;
my $start = ($header_idx >= 0) ? $header_idx + 1 : 0;
for my $i ($start .. $#rows) {
    my @c = @{$rows[$i]};
    my $fname_raw = defined $c[$fcol] ? trim($c[$fcol]) : '';

    # Compose la description : soit les N colonnes de langue (joinées ' / '
    # dans l'ordre des colonnes), soit la colonne « Description » simple.
    my $desc;
    if (@dcols) {
        my @parts;
        for my $j (@dcols) {
            my $v = ($j <= $#c && defined $c[$j]) ? rtrim($c[$j]) : '';
            push @parts, $v if $v ne '';
        }
        $desc = join(' / ', @parts);
    } else {
        $desc = defined $c[$dcol_single] ? rtrim($c[$dcol_single]) : '';
    }

    next if $fname_raw eq '' && trim($desc) eq '';
    next if $fname_raw eq '';
    next if $fname_raw !~ /\./ && trim($desc) eq '';

    # Multi-filename : separer sur , ou ; (avec ou sans espaces)
    my @candidates = grep { $_ ne '' } map { trim($_) } split /\s*[,;]\s*/, $fname_raw;
    next unless @candidates;

    for my $fname (@candidates) {
        my $real = $by_key{ norm_key($fname) };
        if (!defined $real) {
            (my $b = $fname) =~ s/\.[^.]+$//;
            $real = $by_key{ "base:" . lc($b) };
        }
        if (!defined $real) {
            push @unmatched, $fname;
            next;
        }
        $desc =~ s/\r\n/\n/g;
        push @out, [ "$dir/$real", $desc ];
        $used{$real} = 1;
    }
}

# ---------- 5. Ecrire le CSV de sortie ----------
print csv_row("SourceFile", "EXIF:ImageDescription", "IPTC:Caption-Abstract", "XMP-dc:Description");
for my $r (@out) {
    my ($src, $desc) = @$r;
    print csv_row($src, $desc, $desc, $desc);
}

# ---------- Diagnostics ----------
my @no_caption = grep { !$used{$_} } @disk;
print STDERR "ASSOCIES=" . scalar(@out) . "\n";
print STDERR "NON_TROUVES=" . scalar(@unmatched) . "\n";
print STDERR "  -> $_\n" for @unmatched;
print STDERR "TIF_SANS_LEGENDE=" . scalar(@no_caption) . "\n";
print STDERR "  -> $_\n" for @no_caption;

# ================= sous-routines =================

sub trim  { my $s = shift; $s =~ s/^\s+//; $s =~ s/\s+$//; return $s; }
sub rtrim { my $s = shift; $s =~ s/\s+$//; return $s; }
sub norm_key { my $s = lc shift; $s =~ s/^\s+//; $s =~ s/\s+$//; return $s; }

sub read_file_raw {
    my $path = shift;
    open(my $fh, '<:raw', $path) or die "ouverture $path: $!\n";
    local $/; my $data = <$fh>; close $fh;
    $data =~ s/^\x{EF}\x{BB}\x{BF}//;   # retirer BOM UTF-8
    return $data;
}

# Analyse CSV robuste : detecte ; ou , ; gere guillemets, "" echappes, et
# champs multilignes. Retourne une liste de references de tableaux (lignes).
sub parse_csv {
    my $text = shift;
    # detecter le separateur sur la base de la premiere "vraie" ligne
    my $sep = ',';
    {
        my $sample = $text;
        $sample =~ s/".*?"//gs;          # ignorer le contenu des champs cites
        my ($first) = split /\n/, $sample;
        $first = '' unless defined $first;
        my $semi = () = $first =~ /;/g;
        my $comma = () = $first =~ /,/g;
        $sep = ';' if $semi > $comma;
    }
    my @rows;
    my @cur;
    my $field = '';
    my $inq = 0;
    my @ch = split //, $text;
    my $i = 0;
    while ($i <= $#ch) {
        my $c = $ch[$i];
        if ($inq) {
            if ($c eq '"') {
                if ($i + 1 <= $#ch && $ch[$i+1] eq '"') { $field .= '"'; $i += 2; next; }
                $inq = 0; $i++; next;
            }
            $field .= $c; $i++; next;
        } else {
            if ($c eq '"') { $inq = 1; $i++; next; }
            if ($c eq $sep) { push @cur, $field; $field = ''; $i++; next; }
            if ($c eq "\r") { $i++; next; }
            if ($c eq "\n") { push @cur, $field; push @rows, [@cur]; @cur = (); $field = ''; $i++; next; }
            $field .= $c; $i++; next;
        }
    }
    push @cur, $field if ($field ne '' || @cur);
    push @rows, [@cur] if @cur;
    return @rows;
}

# Lecture .xlsx : decompresse avec un module du coeur, lit sharedStrings + sheet1.
sub read_xlsx {
    my $path = shift;
    require IO::Uncompress::Unzip;
    IO::Uncompress::Unzip->import(qw(unzip $UnzipError));

    my $shared = read_zip_member($path, 'xl/sharedStrings.xml');
    my $sheet  = read_zip_member($path, 'xl/worksheets/sheet1.xml');
    die "sheet1.xml introuvable dans le xlsx\n" unless defined $sheet;

    # table des chaines partagees : chaque <si> peut contenir plusieurs <t>
    my @strings;
    if (defined $shared) {
        while ($shared =~ /<si\b[^>]*>(.*?)<\/si>/gs) {
            my $si = $1;
            my $s = '';
            $s .= xml_unescape($1) while $si =~ /<t\b[^>]*>(.*?)<\/t>/gs;
            push @strings, $s;
        }
    }

    # lignes de la feuille
    my @rows;
    while ($sheet =~ /<row\b[^>]*>(.*?)<\/row>/gs) {
        my $rowxml = $1;
        my %cells;
        my $maxcol = 0;
        while ($rowxml =~ /<c\b([^>]*)>(.*?)<\/c>|<c\b([^>]*)\/>/gs) {
            my $attr = defined $1 ? $1 : $3;
            my $body = defined $2 ? $2 : '';
            my ($ref) = $attr =~ /r="([A-Z]+)\d+"/;
            my $col = $ref ? col_to_idx($ref) : 0;
            my ($type) = $attr =~ /t="([^"]+)"/;
            my $val = '';
            if (defined $type && $type eq 's') {
                if ($body =~ /<v>(.*?)<\/v>/s) { $val = $strings[$1] // ''; }
            } elsif (defined $type && $type eq 'inlineStr') {
                $val .= xml_unescape($1) while $body =~ /<t\b[^>]*>(.*?)<\/t>/gs;
            } else {
                if ($body =~ /<v>(.*?)<\/v>/s) { $val = xml_unescape($1); }
            }
            $cells{$col} = $val;
            $maxcol = $col if $col > $maxcol;
        }
        my @line = map { defined $cells{$_} ? $cells{$_} : '' } (0 .. $maxcol);
        push @rows, [@line];
    }

    # Cellules mergees : <mergeCell ref="C2:C5"/>. Pour chaque plage, on
    # propage la valeur de la cellule en haut a gauche dans toutes les cellules
    # vides de la plage. Ainsi, dans une colonne Description, si Mathieu
    # merge 5 cellules verticalement avec une seule legende dans la premiere,
    # les 4 autres heritent automatiquement de cette legende.
    while ($sheet =~ /<mergeCell\s+ref="([A-Z]+)(\d+):([A-Z]+)(\d+)"/g) {
        my ($c1, $r1, $c2, $r2) = (col_to_idx($1), $2 + 0, col_to_idx($3), $4 + 0);
        # Indexation Excel = 1-based, on convertit en 0-based pour les @rows
        my $top_row = $r1 - 1;
        my $bot_row = $r2 - 1;
        next if $top_row > $#rows;
        # Recupere la valeur de la cellule de tete (top-left)
        my $value = ($c1 <= $#{$rows[$top_row]}) ? $rows[$top_row][$c1] : '';
        next unless defined $value && $value ne '';
        # Propage dans toutes les cellules de la plage qui sont vides
        for my $r ($top_row .. $bot_row) {
            next if $r > $#rows;
            for my $c ($c1 .. $c2) {
                # Etend la ligne si trop courte
                while ($#{$rows[$r]} < $c) { push @{$rows[$r]}, ''; }
                next if $r == $top_row && $c == $c1;   # cellule de tete, deja remplie
                if (!defined $rows[$r][$c] || $rows[$r][$c] eq '') {
                    $rows[$r][$c] = $value;
                }
            }
        }
    }

    return @rows;
}

sub read_zip_member {
    my ($path, $member) = @_;
    my $out;
    my $ok = IO::Uncompress::Unzip::unzip($path => \$out, Name => $member);
    return $ok ? $out : undef;
}

sub col_to_idx {
    my $ref = shift;          # ex "AB"
    my $n = 0;
    for my $ch (split //, $ref) { $n = $n * 26 + (ord($ch) - ord('A') + 1); }
    return $n - 1;
}

sub xml_unescape {
    my $s = shift;
    $s =~ s/&lt;/</g;
    $s =~ s/&gt;/>/g;
    $s =~ s/&quot;/"/g;
    $s =~ s/&apos;/'/g;
    $s =~ s/&#x([0-9a-fA-F]+);/chr(hex($1))/ge;
    $s =~ s/&#(\d+);/chr($1)/ge;
    $s =~ s/&amp;/&/g;
    return $s;
}

sub csv_row {
    my @f = @_;
    return join(",", map { csv_quote($_) } @f) . "\n";
}
sub csv_quote {
    my $s = shift;
    $s = '' unless defined $s;
    $s =~ s/"/""/g;
    return "\"$s\"";
}
