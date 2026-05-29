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
        case .scanning:           return "Scanning folder…"
        case .installingExifTool: return "Installing ExifTool (first run)…"
        case .readingSheet:       return "Reading caption file…"
        case .stamping:
            if total > 0 { return "Imprinting captions (\(current)/\(total))" }
            return "Imprinting captions…"
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
            return "No Excel (.xlsx) or CSV (.csv) file found in this folder.\n\nPut your caption file next to the photos and try again."
        case .multipleSheets(let names):
            return "Multiple caption files found:\n• " + names.joined(separator: "\n• ") + "\n\nKeep only one in the folder."
        case .parseFailed(let msg):
            return "Couldn’t read the caption file.\n\n" + msg
        case .noMatches:
            return "No photo in the spreadsheet matches any .tif file in this folder.\n\nCheck that the names in the “Filename” column match your files (case doesn’t matter)."
        case .exifToolUnavailable(let msg):
            return "ExifTool couldn’t be installed: \(msg)\n\nCheck your internet connection and try again (this is only needed the first time)."
        case .exifToolFailed(let msg):
            return "Writing captions failed:\n\n" + msg
        }
    }
}
