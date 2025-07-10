//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public final class PassphraseWordlistManager {
    private static var wordlistsFolder: URL {
        guard let sharedContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.id) else { fatalError() }
        return sharedContainerURL.appendingPathComponent("wordlists")
    }

    public static let customWordlistExtension = "txt"

    private static let maxWordsCount = 10000
    private static let maxWordLength = 30

    public static func getAll() -> [PassphraseWordlist] {
        let builtInWordlists: [PassphraseWordlist] = [.effLarge, .effShort1, .effShort2]
        guard FileManager.default.fileExists(atPath: wordlistsFolder.path) else {
            return builtInWordlists
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: wordlistsFolder.path)
            let customWordlists = files.map { PassphraseWordlist.custom($0) }
            return builtInWordlists + customWordlists
        } catch {
            Diag.error("Failed to enumerate wordlist files [message: \(error.localizedDescription)]")
            return builtInWordlists
        }
    }

    public static func load(_ wordlist: PassphraseWordlist) -> StringSet? {
        Diag.debug("Will load wordlist [fileName: \(wordlist.fileName)]")
        let resourcePath = { () -> URL? in
            switch wordlist {
            case .custom:
                return wordlistsFolder.appendingPathComponent(wordlist.fileName)
            default:
                return Bundle.framework.url(
                    forResource: wordlist.fileName,
                    withExtension: "",
                    subdirectory: ""
                )
            }
        }()
        guard let resourcePath else {
            Diag.error("Failed to find wordlist file [fileName: \(wordlist.fileName)]")
            return nil
        }

        do {
            let data = try String(contentsOf: resourcePath)
            var stringSet = StringSet()
            data.enumerateLines { line, _ in
                stringSet.insert(line)
            }
            Diag.debug("Wordlist loaded successfully")
            return stringSet
        } catch {
            Diag.error("Failed to load wordlist [message: \(error.localizedDescription)]")
            return nil
        }
    }

    public static func delete(_ wordlist: PassphraseWordlist) {
        guard case let .custom(fileName) = wordlist else {
            assertionFailure("Only custom worldlist can be deletale")
            return
        }
        let fileUrl = wordlistsFolder.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            Diag.error("Failed to delete custom wordlist [message: \(error.localizedDescription)]")
        }
    }
}

extension PassphraseWordlistManager {
    public enum ImportError: Error, LocalizedError {
        case importError(_ lineNumber: Int, _ type: ProblemType)

        public enum ProblemType: String, CustomStringConvertible {
            case tooFewWords
            case tooManyWords
            case tooLongWord
            case duplicateWord
            case unexpectedLineFormat

            public var description: String {
                return rawValue
            }
        }
        public var errorDescription: String? {
            switch self {
            case let .importError(lineNumber, problem):
                return String.localizedStringWithFormat(
                    LString.PasswordGenerator.Wordlist.importFailedMessageTemplate,
                    lineNumber,
                    problem.description
                )
            }
        }
    }

    public static func `import`(from fileURL: URL) throws -> PassphraseWordlist {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: wordlistsFolder.path) {
            try fileManager.createDirectory(at: wordlistsFolder, withIntermediateDirectories: true)
        }

        var stringSet = StringSet()
        let incomingFileText = try loadTextFile(from: fileURL)
        var lineNumber = 1
        var importError: ImportError?
        incomingFileText.enumerateLines { line, shouldStop in
            if let lineError = processLine(line, lineNumber, addTo: &stringSet) {
                importError = lineError
                shouldStop = true
                return
            }
            lineNumber += 1
        }
        guard importError == nil else {
            throw importError!
        }
        guard stringSet.count > 1 else {
            throw ImportError.importError(lineNumber, .tooFewWords)
        }

        let sanitizedContent = stringSet.sorted().joined(separator: "\n")

        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let targetFileURL = wordlistsFolder.appendingPathComponent(fileName)
        try sanitizedContent.write(to: targetFileURL, atomically: false, encoding: .utf8)
        Diag.info("Wordlist imported successfully")

        return .custom(fileName)
    }

    private static func loadTextFile(from fileURL: URL) throws -> String {
        assert(fileURL.isFileURL, "Non-file URLs are not supported")
        _ = fileURL.startAccessingSecurityScopedResource()
        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }
        let fileText = try String(contentsOf: fileURL)
        return fileText
    }

    private static func processLine(
        _ line: String,
        _ lineNumber: Int,
        addTo stringSet: inout StringSet
    ) -> ImportError? {
        guard lineNumber < maxWordsCount else {
            return ImportError.importError(lineNumber, .tooManyWords)
        }

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLine.isNotEmpty else {
            return nil
        }

        let word: String
        let parts = trimmedLine.components(separatedBy: .whitespaces)
        switch parts.count {
        case 1:
            word = trimmedLine
        case 2:
            guard let _ = Int(parts[0]) else {
                return ImportError.importError(lineNumber, .unexpectedLineFormat)
            }
            word = parts[1]
        default:
            return ImportError.importError(lineNumber, .unexpectedLineFormat)
        }

        guard word.count < maxWordLength else {
            return ImportError.importError(lineNumber, .tooLongWord)
        }

        let outcome = stringSet.insert(word)
        guard outcome.inserted else {
            return ImportError.importError(lineNumber, .duplicateWord)
        }
        return nil
    }
}

extension LString.PasswordGenerator.Wordlist {
    public static let importFailedMessageTemplate = NSLocalizedString(
        "[PasswordGenerator/Wordlist/ImportError/reason]",
        bundle: Bundle.framework,
        value: "File could not be imported because of a problem in line %d (%@)",
        comment: "Error message when importing a text file [lineNumber: Int, problemDescription: String]"
    )
}
