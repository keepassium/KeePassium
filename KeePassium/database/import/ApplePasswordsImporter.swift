//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

public class ApplePasswordsImporter {
    private enum CSVColumn: Int, CaseIterable {
        case title
        case url
        case username
        case password
        case notes
        case otp

        var expectedName: String {
            switch self {
            case .title:
                return "Title"
            case .url:
                return "URL"
            case .username:
                return "Username"
            case .password:
                return "Password"
            case .notes:
                return "Notes"
            case .otp:
                return "OTPAuth"
            }
        }
    }

    public enum ImportError: LocalizedError {
        case emptyFile
        case invalidFormat(lineNumber: Int, columnNumber: Int?)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return LString.Error.importEmptyIncomingFile
            case let .invalidFormat(lineNumber, columnNumber):
                if let columnNumber {
                    return String.localizedStringWithFormat(
                        LString.Error.importCSVInvalidFormatWithColumnTemplate,
                        lineNumber,
                        columnNumber
                    )
                } else {
                    return String.localizedStringWithFormat(
                        LString.Error.importCSVInvalidFormatTemplate,
                        lineNumber
                    )

                }
            }
        }
    }

    public init(){}

    public func importFromCSV(fileURL: URL, group: Group) throws -> [Entry] {
        let csvContent = try String(contentsOf: fileURL, encoding: .utf8)

        let parsedRows = try parseCSV(csvContent)
        guard parsedRows.count > 1 else {
            Diag.error("Incoming CSV file is empty")
            throw ImportError.emptyFile
        }

        let headerRow = parsedRows[0]
        guard headerRow.count == CSVColumn.allCases.count else {
            Diag.error("Unexpected number of columns in header [expected: \(CSVColumn.allCases.count), actual: \(headerRow.count)]")
            throw ImportError.invalidFormat(lineNumber: 1, columnNumber: nil)
        }

        for column in CSVColumn.allCases {
            let actualName = headerRow[column.rawValue]
            guard actualName == column.expectedName else {
                Diag.error("Unexpected column in CSV header [expected: \(column.expectedName), actual: \(actualName)]")
                let colIndex = Self.getStartPosition(ofColumn: column.rawValue, in: headerRow)
                throw ImportError.invalidFormat(lineNumber: 1, columnNumber: colIndex + 1)
            }
        }

        let dataRows = Array(parsedRows.dropFirst())

        return dataRows.enumerated().map { index, fields in
            let entry: Entry = group.createEntry(detached: true)

            entry.rawTitle = fields[CSVColumn.title.rawValue]
            entry.rawURL = fields[CSVColumn.url.rawValue]
            entry.rawUserName = fields[CSVColumn.username.rawValue]
            entry.rawPassword = fields[CSVColumn.password.rawValue]
            entry.rawNotes = fields[CSVColumn.notes.rawValue]

            let otp = fields[CSVColumn.otp.rawValue]
            if TOTPGeneratorFactory.isValidURI(otp) {
                entry.setField(name: EntryField.otp, value: otp, isProtected: true)
            }

            entry.touch(.modified)

            return entry
        }
    }

    private func parseCSV(_ rawCSVContent: String) throws -> [[String]] {
        let csvContent = rawCSVContent.replacingOccurrences(of: "\r\n", with: "\n")

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInQuotes = false
        var lineNumber = 1
        var colNumber = 1

        var index = csvContent.startIndex
        while index < csvContent.endIndex {
            let char = csvContent[index]

            switch char {
            case "\"":
                if isInQuotes {
                    let nextIndex = csvContent.index(after: index)
                    if nextIndex < csvContent.endIndex && csvContent[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        isInQuotes = false
                    }
                } else {
                    isInQuotes = true
                }

            case ",":
                if isInQuotes {
                    currentField.append(char)
                } else {
                    currentRow.append(currentField)
                    currentField = ""
                }

            case "\r":
                assertionFailure("This should have been filtered out earlier")
                fallthrough

            case "\n":
                if isInQuotes {
                    currentField.append("\n")
                } else {
                    if !currentField.isEmpty || !currentRow.isEmpty {
                        currentRow.append(currentField)
                        rows.append(currentRow)
                        currentRow = []
                        currentField = ""
                    }
                    lineNumber += 1
                    colNumber = 0
                }

            default:
                currentField.append(char)
            }

            colNumber += 1
            index = csvContent.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        if let headerColCount = rows.first?.count {
            for (i, row) in rows.enumerated().dropFirst() {
                let colCount = row.count
                if colCount != headerColCount {
                    let lineNumber = i + 1
                    Diag.error("Unexpected number of columns [line: \(lineNumber), expected: \(headerColCount), actual: \(colCount)]")
                    let colIndex = Self.getStartPosition(ofColumn: colCount, in: row)
                    throw ImportError.invalidFormat(lineNumber: lineNumber, columnNumber: colIndex + 1)
                }
            }
        }

        if isInQuotes {
            Diag.error("Unclosed quotes [line: \(lineNumber)]")
            throw ImportError.invalidFormat(lineNumber: lineNumber, columnNumber: nil)
        }

        return rows
    }

    static func getStartPosition(ofColumn columnIndex: Int, in row: [String]) -> Int {
        var result = 0
        for column in 0..<row.count {
            if column >= columnIndex {
                return result
            }
            result += row[column].count + 1
        }
        return result - 1
    }
}
