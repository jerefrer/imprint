import Foundation
import SwiftUI

@MainActor
final class ImprintEngine: ObservableObject {
    @Published var state: AppState = .idle

    private var supportDir: URL {
        let lib = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return lib.appendingPathComponent("Imprint", isDirectory: true)
    }

    private var parserURL: URL {
        // parse_sheet.pl est copié dans Contents/Resources/ par build_app.sh
        if let path = Bundle.main.path(forResource: "parse_sheet", ofType: "pl") {
            return URL(fileURLWithPath: path)
        }
        // Repli pour `swift run` en dev (script à côté des sources)
        return URL(fileURLWithPath: "app/parse_sheet.pl")
    }

    // MARK: - Public API

    func start(folder: URL) {
        Task { await runPipeline(folder: folder) }
    }

    func reset() {
        state = .idle
    }

    // MARK: - Pipeline

    private func updateProgress(_ progress: ProcessingProgress) {
        state = .processing(progress)
    }

    private func runPipeline(folder: URL) async {
        do {
            updateProgress(.init(phase: .scanning))
            let sheet = try findSheet(in: folder)

            updateProgress(.init(phase: .installingExifTool))
            let exiftool = try await ensureExifTool()

            updateProgress(.init(phase: .readingSheet))
            let parseResult = try runParser(folder: folder, sheet: sheet)

            guard parseResult.toStamp > 0 else {
                state = .done(.failure(.noMatches))
                return
            }

            updateProgress(.init(phase: .stamping, total: parseResult.toStamp))
            try await runExifTool(
                exiftool: exiftool,
                csvPath: parseResult.csvPath,
                folder: folder
            )
            // exiftool a tourné jusqu'au bout sans exception : toutes les lignes
            // du CSV ont été appliquées (sinon runExifTool aurait throw).
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: parseResult.csvPath))

            var files: [FileResult] = []
            for entry in parseResult.stamped {
                files.append(.init(filename: entry.filename, caption: entry.caption, status: .stamped))
            }
            for name in parseResult.untaggedTifs {
                files.append(.init(filename: name, caption: nil, status: .noCaption))
            }
            for name in parseResult.unmatchedRows {
                files.append(.init(filename: name, caption: nil, status: .missingFile))
            }

            let summary = ProcessSummary(
                folder: folder,
                sheetName: sheet.lastPathComponent,
                updatedCount: parseResult.toStamp,
                files: files
            )
            state = .done(.success(summary))
        } catch let error as ImprintError {
            state = .done(.failure(error))
        } catch {
            state = .done(.failure(.parseFailed(error.localizedDescription)))
        }
    }

    // MARK: - Sheet detection

    private func findSheet(in folder: URL) throws -> URL {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let candidates = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            guard ext == "xlsx" || ext == "csv" else { return false }
            let name = url.lastPathComponent
            // Ignore les fichiers temporaires Excel ("~$…") et verrous LibreOffice (".~lock…")
            if name.hasPrefix("~") || name.hasPrefix(".~") || name.hasPrefix(".") {
                return false
            }
            return true
        }
        if candidates.isEmpty {
            throw ImprintError.noSheetFound
        }
        if candidates.count > 1 {
            // Préférer xlsx s'il y en a un seul, sinon erreur explicite
            let xlsx = candidates.filter { $0.pathExtension.lowercased() == "xlsx" }
            if xlsx.count == 1 { return xlsx[0] }
            throw ImprintError.multipleSheets(candidates.map { $0.lastPathComponent })
        }
        return candidates[0]
    }

    // MARK: - ExifTool installation

    private func ensureExifTool() async throws -> URL {
        // 1. Cherche un ExifTool déjà installé
        for candidate in ["/usr/local/bin/exiftool", "/opt/homebrew/bin/exiftool"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        if let path = lookupInPATH("exiftool") {
            return URL(fileURLWithPath: path)
        }

        // 2. Cherche une installation précédente dans le support folder
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let existing = (try? FileManager.default.contentsOfDirectory(
            at: supportDir,
            includingPropertiesForKeys: nil
        )) ?? []
        let existingTool = existing
            .filter { $0.lastPathComponent.hasPrefix("Image-ExifTool-") }
            .sorted { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }
            .first
            .map { $0.appendingPathComponent("exiftool") }
        if let url = existingTool, FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }

        // 3. Télécharge la dernière version depuis exiftool.org
        return try await downloadExifTool()
    }

    private func lookupInPATH(_ tool: String) -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") {
            let candidate = "\(dir)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func downloadExifTool() async throws -> URL {
        let session = URLSession.shared
        // 1. Lit la version courante
        let versionURL = URL(string: "https://exiftool.org/ver.txt")!
        let (verData, _) = try await session.data(from: versionURL)
        let version = String(data: verData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !version.isEmpty else {
            throw ImprintError.exifToolUnavailable("Version not found on exiftool.org")
        }

        // 2. Télécharge le tarball
        let tgzURL = URL(string: "https://exiftool.org/Image-ExifTool-\(version).tar.gz")!
        let (tgzLocalURL, _) = try await session.download(from: tgzURL)
        let targetTgz = supportDir.appendingPathComponent("Image-ExifTool-\(version).tar.gz")
        try? FileManager.default.removeItem(at: targetTgz)
        try FileManager.default.moveItem(at: tgzLocalURL, to: targetTgz)

        // 3. Décompresse via tar
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", targetTgz.path, "-C", supportDir.path]
        try tar.run()
        tar.waitUntilExit()
        if tar.terminationStatus != 0 {
            throw ImprintError.exifToolUnavailable("Extraction failed (tar)")
        }

        let exiftoolURL = supportDir
            .appendingPathComponent("Image-ExifTool-\(version)")
            .appendingPathComponent("exiftool")
        // Marque exécutable
        try? FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: exiftoolURL.path
        )
        guard FileManager.default.isExecutableFile(atPath: exiftoolURL.path) else {
            throw ImprintError.exifToolUnavailable("Binary not found after extraction")
        }
        return exiftoolURL
    }

    // MARK: - Parser (parse_sheet.pl)

    struct ParseResult {
        let csvPath: String
        let toStamp: Int                                            // ASSOCIES
        let stamped: [(filename: String, caption: String)]          // from CSV
        let unmatchedRows: [String]                                 // NON_TROUVES
        let untaggedTifs: [String]                                  // TIF_SANS_LEGENDE
    }

    private func runParser(folder: URL, sheet: URL) throws -> ParseResult {
        let csvPath = "/tmp/imprint-\(UUID().uuidString).csv"
        FileManager.default.createFile(atPath: csvPath, contents: nil)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [parserURL.path, folder.path, sheet.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let msg = String(data: stderr, encoding: .utf8) ?? "code \(process.terminationStatus)"
            throw ImprintError.parseFailed(msg)
        }

        // Écrit le CSV (utilisé par exiftool ensuite)
        try stdout.write(to: URL(fileURLWithPath: csvPath))

        // Parse CSV proprement (gère les champs multilignes entre guillemets,
        // les "" échappés). Skip header row. Colonnes : SourceFile, EXIF:Imag…,
        // IPTC:Caption-Abstract, XMP-dc:Description.
        let csvText = String(data: stdout, encoding: .utf8) ?? ""
        let rows = ImprintEngine.parseCSVRows(csvText)
        var stamped: [(filename: String, caption: String)] = []
        for row in rows.dropFirst() where row.count >= 2 {
            let path = row[0]
            let caption = row[1]
            let filename = (path as NSString).lastPathComponent
            stamped.append((filename: filename, caption: caption))
        }

        // Parse stderr pour stats + listes
        let errText = String(data: stderr, encoding: .utf8) ?? ""
        var associated = 0
        var unmatched: [String] = []
        var untagged: [String] = []
        enum Section { case none, unmatched, untagged }
        var section: Section = .none
        for raw in errText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("ASSOCIES=") {
                associated = Int(line.dropFirst("ASSOCIES=".count)) ?? 0
                section = .none
            } else if line.hasPrefix("NON_TROUVES=") {
                section = .unmatched
            } else if line.hasPrefix("TIF_SANS_LEGENDE=") {
                section = .untagged
            } else if line.hasPrefix("  -> ") {
                let name = String(line.dropFirst(5))
                switch section {
                case .unmatched: unmatched.append(name)
                case .untagged:  untagged.append(name)
                case .none: break
                }
            }
        }

        return ParseResult(
            csvPath: csvPath,
            toStamp: associated,
            stamped: stamped,
            unmatchedRows: unmatched,
            untaggedTifs: untagged
        )
    }

    /// Parseur CSV minimaliste qui respecte les guillemets et les "" échappés.
    /// Suffisant pour le format produit par parse_sheet.pl (tous les champs quotés).
    static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var idx = text.startIndex

        while idx < text.endIndex {
            let c = text[idx]
            if inQuotes {
                if c == "\"" {
                    let next = text.index(after: idx)
                    if next < text.endIndex && text[next] == "\"" {
                        currentField.append("\"")
                        idx = text.index(after: next)
                    } else {
                        inQuotes = false
                        idx = text.index(after: idx)
                    }
                } else {
                    currentField.append(c)
                    idx = text.index(after: idx)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                    idx = text.index(after: idx)
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                    idx = text.index(after: idx)
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                    idx = text.index(after: idx)
                case "\r":
                    idx = text.index(after: idx)
                default:
                    currentField.append(c)
                    idx = text.index(after: idx)
                }
            }
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }

    // MARK: - ExifTool execution

    /// État mutable partagé entre les readability handlers et le termination handler.
    /// Encapsulé dans une classe pour éviter les captures mutables (Swift 6 strict concurrency).
    private final class ExifToolRunState: @unchecked Sendable {
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        var stdoutCollected = Data()   // pour le diagnostic d'erreur
        var processedFiles = 0
        var lastSeen: String?

        /// Append le chunk dans le buffer pointé par keyPath, puis scanne pour
        /// les lignes "======== filename" (-progress d'exiftool). Pour chaque
        /// fichier vu, incrémente le compteur et appelle onProgress.
        func scanForProgress(
            chunk: Data,
            buffer: ReferenceWritableKeyPath<ExifToolRunState, Data>,
            onProgress: (Int, String?) -> Void
        ) {
            self[keyPath: buffer].append(chunk)
            while let nlIdx = self[keyPath: buffer].firstIndex(of: 0x0a) {
                let lineData = self[keyPath: buffer][..<nlIdx]
                self[keyPath: buffer] = self[keyPath: buffer][self[keyPath: buffer].index(after: nlIdx)...]
                guard let line = String(data: lineData, encoding: .utf8) else { continue }
                if line.hasPrefix("========") {
                    // Format ExifTool -progress : "======== /chemin/full/fichier.tif [N/M]"
                    // On retire le suffixe " [N/M]" (déjà dans le titre) et on
                    // ne garde que le nom du fichier (le chemin complet ne sert à rien
                    // à l'utilisateur, qui sait déjà dans quel dossier il a déposé).
                    var raw = String(line.drop { $0 == "=" || $0 == " " })
                    if let range = raw.range(of: #" \[\d+/\d+\]$"#, options: .regularExpression) {
                        raw.removeSubrange(range)
                    }
                    let filename = (raw as NSString).lastPathComponent
                    lastSeen = filename
                    processedFiles += 1
                    onProgress(processedFiles, lastSeen)
                }
            }
        }
    }

    private func runExifTool(exiftool: URL, csvPath: String, folder: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = exiftool
            process.arguments = [
                "-progress",
                "-csv=\(csvPath)",
                "-overwrite_original",
                "-P",
                "-charset", "filename=UTF8",
                "-charset", "iptc=UTF8",
                "-codedcharacterset=utf8",
                "-ext", "tif",
                "-ext", "tiff",
                folder.path
            ]
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let runState = ExifToolRunState()
            weak var weakSelf = self

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                runState.stdoutCollected.append(chunk)
                runState.scanForProgress(chunk: chunk, buffer: \.stdoutBuffer) { processed, file in
                    Task { @MainActor in
                        guard let engine = weakSelf else { return }
                        if case .processing(var p) = engine.state {
                            p.current = processed
                            p.currentFile = file
                            engine.state = .processing(p)
                        }
                    }
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                runState.scanForProgress(chunk: chunk, buffer: \.stderrBuffer) { processed, file in
                    Task { @MainActor in
                        guard let engine = weakSelf else { return }
                        if case .processing(var p) = engine.state {
                            p.current = processed
                            p.currentFile = file
                            engine.state = .processing(p)
                        }
                    }
                }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if proc.terminationStatus != 0 {
                    let stderr = String(data: runState.stderrBuffer, encoding: .utf8) ?? ""
                    let stdout = String(data: runState.stdoutCollected, encoding: .utf8) ?? ""
                    let msg = !stderr.isEmpty ? stderr : (stdout.isEmpty ? "code \(proc.terminationStatus)" : stdout)
                    continuation.resume(throwing: ImprintError.exifToolFailed(msg))
                    return
                }
                continuation.resume(returning: ())
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ImprintError.exifToolFailed(error.localizedDescription))
            }
        }
    }
}
