import Foundation

enum AppState {
    case idle
    case processing(ProcessingProgress)
    case done(Result<ProcessSummary, ImprintError>)
}

struct ProcessingProgress {
    var phase: Phase
    var current: Int = 0
    var total: Int = 0
    var currentFile: String? = nil

    enum Phase {
        case scanning           // listing folder + finding sheet
        case installingExifTool // download exiftool, 1st run
        case readingSheet       // running parse_sheet.pl
        case stamping           // running exiftool
    }

    var label: String {
        switch phase {
        case .scanning:           return "Lecture du dossier…"
        case .installingExifTool: return "Première installation d'ExifTool…"
        case .readingSheet:       return "Lecture du fichier de légendes…"
        case .stamping:
            if total > 0 { return "Application des légendes (\(current)/\(total))" }
            return "Application des légendes…"
        }
    }

    var isDeterminate: Bool { phase == .stamping && total > 0 }
    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

struct ProcessSummary {
    let folder: URL
    let sheetName: String
    let updatedCount: Int
    let files: [FileResult]

    var stampedCount: Int    { files.filter { $0.status == .stamped }.count }
    var noCaptionCount: Int  { files.filter { $0.status == .noCaption }.count }
    var missingFileCount: Int { files.filter { $0.status == .missingFile }.count }
}

struct FileResult: Identifiable, Equatable {
    let id = UUID()
    let filename: String
    let status: Status

    enum Status: Equatable {
        case stamped       // .tif présent, légende écrite
        case noCaption     // .tif présent, pas de légende dans le tableau
        case missingFile   // ligne du tableau sans .tif correspondant
    }
}

enum ImprintError: LocalizedError {
    case noSheetFound
    case multipleSheets([String])
    case parseFailed(String)
    case noMatches
    case exifToolUnavailable(String)
    case exifToolFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSheetFound:
            return "Aucun fichier Excel (.xlsx) ni CSV (.csv) trouvé dans ce dossier.\n\nPlacez votre fichier de légendes avec les photos, puis recommencez."
        case .multipleSheets(let names):
            return "Plusieurs fichiers de légendes trouvés :\n• " + names.joined(separator: "\n• ") + "\n\nGardez-en un seul dans le dossier."
        case .parseFailed(let msg):
            return "Lecture du fichier de légendes impossible.\n\n" + msg
        case .noMatches:
            return "Aucune photo du tableau ne correspond à un fichier .tif présent dans le dossier.\n\nVérifiez que les noms de la colonne « Filename » correspondent aux fichiers (la casse n'a pas d'importance)."
        case .exifToolUnavailable(let msg):
            return "ExifTool n'a pas pu être installé : \(msg)\n\nVérifiez votre connexion Internet et recommencez (l'installation n'est nécessaire qu'une seule fois)."
        case .exifToolFailed(let msg):
            return "L'écriture des légendes a échoué :\n\n" + msg
        }
    }
}
