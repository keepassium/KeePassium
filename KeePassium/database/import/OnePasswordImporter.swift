//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import zlib

public class OnePasswordImporter {
    private struct OnePasswordVault: Decodable {
        let accounts: [OnePasswordAccount]
    }

    private struct OnePasswordAccount: Decodable {
        let vaults: [OnePasswordVaultContainer]
    }

    private struct OnePasswordVaultContainer: Decodable {
        let items: [OnePasswordItem]
    }

    private struct OnePasswordItem: Decodable {
        let uuid: String
        let createdAt: Double?
        let updatedAt: Double?
        let state: String?
        let overview: OnePasswordOverview
        let details: OnePasswordDetails?
    }

    private struct OnePasswordOverview: Decodable {
        let title: String
        let url: String?
        let urls: [OnePasswordURL]?
        let tags: [String]?
    }

    private struct OnePasswordURL: Decodable {
        let label: String?
        let url: String
    }

    private struct OnePasswordDetails: Decodable {
        let loginFields: [OnePasswordLoginField]?
        let notesPlain: String?
        let sections: [OnePasswordSection]?
        let passwordHistory: [OnePasswordHistoryEntry]?
        let documentAttributes: OnePasswordDocumentAttributes?
    }

    private struct OnePasswordLoginField: Decodable {
        let value: String?
        let name: String?
        let type: String?
        let designation: String?
    }

    private struct OnePasswordSection: Decodable {
        let title: String?
        let name: String?
        let fields: [OnePasswordField]?
    }

    private struct OnePasswordFileValue: Decodable {
        let fileName: String?
        let documentId: String?
        let decryptedSize: Int?
    }

    private struct OnePasswordField: Decodable {
        let title: String?
        let id: String?
        let value: String?
        let file: OnePasswordFileValue?
        let type: String?

        private struct ValueWrapper: Decodable {
            let totp: String?
            let concealed: String?
            let string: String?
            let date: Double?
            let monthYear: Int?
            let file: OnePasswordFileValue?
        }

        enum CodingKeys: String, CodingKey {
            case title, id, value, type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            type = try container.decodeIfPresent(String.self, forKey: .type)

            if let stringValue = try? container.decode(String.self, forKey: .value) {
                value = stringValue
                file = nil
            } else if let dictValue = try? container.decode(ValueWrapper.self, forKey: .value) {
                if let fileValue = dictValue.file {
                    file = fileValue
                    value = nil
                } else if let totp = dictValue.totp {
                    value = totp
                    file = nil
                } else if let concealed = dictValue.concealed {
                    value = concealed
                    file = nil
                } else if let string = dictValue.string {
                    value = string
                    file = nil
                } else if let date = dictValue.date {
                    let dateValue = Date(timeIntervalSince1970: date)
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .none
                    value = formatter.string(from: dateValue)
                    file = nil
                } else {
                    value = nil
                    file = nil
                }
            } else {
                value = nil
                file = nil
            }
        }
    }

    private struct OnePasswordHistoryEntry: Decodable {
        let value: String?
        let time: Double
    }

    private struct OnePasswordDocumentAttributes: Decodable {
        let fileName: String?
        let documentId: String?
        let decryptedSize: Int?
    }

    private struct ZIPArchive {
        struct Entry {
            let fileName: String
            let compressedSize: UInt32
            let uncompressedSize: UInt32
            let compressionMethod: UInt16
            let localHeaderOffset: UInt32
            let crc32: UInt32
        }

        let data: Data
        let entries: [Entry]

        init(data: Data) throws {
            self.data = data

            guard let eocdOffset = data.lastRange(of: Data([0x50, 0x4b, 0x05, 0x06]))?.lowerBound else {
                throw ImportError.invalidZIPFormat(reason: "Invalid ZIP: End of Central Directory not found")
            }

            let cdEntries = data.readUInt16LE(at: eocdOffset + 10)
            let cdOffset = data.readUInt32LE(at: eocdOffset + 16)

            var entries: [Entry] = []
            var offset = Int(cdOffset)

            for _ in 0..<cdEntries {
                guard data.readUInt32LE(at: offset) == 0x02014b50 else {
                    throw ImportError.invalidZIPFormat(reason: "Invalid Central Directory entry")
                }

                let compressionMethod = data.readUInt16LE(at: offset + 10)
                let crc32 = data.readUInt32LE(at: offset + 16)
                let compressedSize = data.readUInt32LE(at: offset + 20)
                let uncompressedSize = data.readUInt32LE(at: offset + 24)
                let fileNameLength = Int(data.readUInt16LE(at: offset + 28))
                let extraFieldLength = Int(data.readUInt16LE(at: offset + 30))
                let commentLength = Int(data.readUInt16LE(at: offset + 32))
                let localHeaderOffset = data.readUInt32LE(at: offset + 42)

                let fileNameData = data.subdata(in: (offset + 46)..<(offset + 46 + fileNameLength))
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    throw ImportError.invalidZIPFormat(reason: "Invalid file name encoding")
                }

                let entry = Entry(
                    fileName: fileName,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    compressionMethod: compressionMethod,
                    localHeaderOffset: localHeaderOffset,
                    crc32: crc32
                )
                entries.append(entry)

                offset += 46 + fileNameLength + extraFieldLength + commentLength
            }

            self.entries = entries
        }

        func extractData(for entry: Entry) throws -> Data {
            let localHeaderOffset = Int(entry.localHeaderOffset)

            guard data.readUInt32LE(at: localHeaderOffset) == 0x04034b50 else {
                throw ImportError.invalidZIPFormat(reason: "Invalid local file header")
            }

            let fileNameLength = Int(data.readUInt16LE(at: localHeaderOffset + 26))
            let extraFieldLength = Int(data.readUInt16LE(at: localHeaderOffset + 28))

            let dataOffset = localHeaderOffset + 30 + fileNameLength + extraFieldLength
            let compressedData = data.subdata(in: dataOffset..<(dataOffset + Int(entry.compressedSize)))

            if entry.compressionMethod == 0 {
                return compressedData
            } else if entry.compressionMethod == 8 {
                var decompressed = Data()
                var stream = z_stream()

                let result = compressedData.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Int32 in
                    stream.next_in = UnsafeMutablePointer<UInt8>(mutating: input.bindMemory(to: UInt8.self).baseAddress)
                    stream.avail_in = UInt32(compressedData.count)

                    var status = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                    guard status == Z_OK else {
                        return status
                    }

                    decompressed = Data(count: Int(entry.uncompressedSize))
                    decompressed.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
                        stream.next_out = output.bindMemory(to: UInt8.self).baseAddress
                        stream.avail_out = UInt32(entry.uncompressedSize)
                        status = inflate(&stream, Z_FINISH)
                    }

                    inflateEnd(&stream)
                    return status
                }

                guard result == Z_STREAM_END else {
                    throw ImportError.invalidZIPFormat(reason: "Decompression failed")
                }

                return decompressed
            } else {
                throw ImportError.invalidZIPFormat(reason: "Unsupported compression method: \(entry.compressionMethod)")
            }
        }
    }

    public enum ImportError: LocalizedError {
        case emptyFile
        case invalidZIPFormat(reason: String)
        case parsingFailed(reason: String)
        case corruptedAttachmentData(itemName: String, attachmentName: String)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return LString.Error.importOnePasswordEmptyFile
            case let .invalidZIPFormat(reason):
                return String.localizedStringWithFormat(
                    LString.Error.importOnePasswordInvalidZIPFormat,
                    reason
                )
            case let .parsingFailed(reason):
                return String.localizedStringWithFormat(
                    LString.Error.importOnePasswordParsingFailed,
                    reason
                )
            case let .corruptedAttachmentData(itemName, attachmentName):
                return String.localizedStringWithFormat(
                    LString.Error.importOnePasswordCorruptedAttachmentData,
                    itemName,
                    attachmentName
                )
            }
        }
    }

    public init() {}

    public func importFrom1PUX(fileURL: URL, group: Group) throws -> ([Entry], [Group]) {
        let exportData = try extractExportData(from: fileURL)

        guard let jsonData = exportData.data(using: .utf8) else {
            throw ImportError.parsingFailed(reason: "Could not convert export.data to UTF-8")
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            let vault = try decoder.decode(OnePasswordVault.self, from: jsonData)

            let allItems = vault.accounts.flatMap { $0.vaults.flatMap { $0.items } }
            guard !allItems.isEmpty else {
                Diag.error("No items found in 1Password vault")
                throw ImportError.emptyFile
            }

            var entries: [Entry] = []

            for account in vault.accounts {
                for vaultContainer in account.vaults {
                    for item in vaultContainer.items {
                        let entry = try createEntry(from: item, in: group, zipFileURL: fileURL)
                        entries.append(entry)
                    }
                }
            }

            return (entries, [])
        } catch let decodingError as DecodingError {
            Diag.error("Failed to decode 1Password JSON: \(decodingError)")
            throw ImportError.parsingFailed(reason: decodingError.localizedDescription)
        } catch {
            Diag.error("Unexpected error during 1Password import: \(error)")
            throw error
        }
    }

    private func createEntry(from item: OnePasswordItem, in group: Group, zipFileURL: URL) throws -> Entry {
        let creationDate = item.createdAt.map { Date(timeIntervalSince1970: $0) } ?? Date()

        let entry: Entry = group.createEntry(creationDate: creationDate, detached: true)

        entry.rawTitle = item.overview.title

        if let notes = item.details?.notesPlain, !notes.isEmpty {
            entry.rawNotes = notes
        }

        if let loginFields = item.details?.loginFields {
            for field in loginFields {
                if field.designation == "username" {
                    entry.rawUserName = field.value ?? ""
                } else if field.designation == "password" {
                    entry.rawPassword = field.value ?? ""
                }
            }
        }

        if let url = item.overview.url, !url.isEmpty {
            entry.rawURL = url
        } else if let urls = item.overview.urls, let firstURL = urls.first?.url {
            entry.rawURL = firstURL
        }

        if let tags = item.overview.tags, !tags.isEmpty {
            entry.tags = tags
        }

        if let sections = item.details?.sections {
            for section in sections {
                if let fields = section.fields {
                    for field in fields {
                        try processField(
                            field,
                            for: entry,
                            parentGroup: group,
                            zipFileURL: zipFileURL,
                            itemTitle: item.overview.title
                        )
                    }
                }
            }
        }

        if let updatedAt = item.updatedAt {
            let modificationDate = Date(timeIntervalSince1970: updatedAt)
            entry.touch(.modifiedAt(modificationDate))
        } else {
            entry.touch(.modified)
        }

        if let passwordHistory = item.details?.passwordHistory {
            try addPasswordHistory(passwordHistory, to: entry, parentGroup: group)
        }

        if let documentAttributes = item.details?.documentAttributes {
            try addAttachment(
                documentAttributes,
                to: entry,
                parentGroup: group,
                zipFileURL: zipFileURL,
                itemTitle: item.overview.title
            )
        }

        return entry
    }

    private func processField(
        _ field: OnePasswordField,
        for entry: Entry,
        parentGroup: Group,
        zipFileURL: URL,
        itemTitle: String
    ) throws {
        if let fileValue = field.file {
            let attrs = OnePasswordDocumentAttributes(
                fileName: fileValue.fileName,
                documentId: fileValue.documentId,
                decryptedSize: fileValue.decryptedSize
            )
            try addAttachment(attrs, to: entry, parentGroup: parentGroup, zipFileURL: zipFileURL, itemTitle: itemTitle)
            return
        }

        guard let value = field.value, !value.isEmpty else {
            return
        }

        if value.hasPrefix("otpauth://") {
            if TOTPGeneratorFactory.isValidURI(value) {
                entry.setField(name: EntryField.otp, value: value, isProtected: true)
            }
            return
        }

        if let title = field.title, !title.isEmpty {
            let isProtected = field.type == "P"
            entry.setField(name: title, value: value, isProtected: isProtected)
        }
    }

    private func addPasswordHistory(_ history: [OnePasswordHistoryEntry], to entry: Entry, parentGroup: Group) throws {
        guard !history.isEmpty else { return }

        if let entry2 = entry as? Entry2 {
            for historyItem in history {
                if let password = historyItem.value {
                    let historyDate = Date(timeIntervalSince1970: historyItem.time)

                    if let historyEntry = parentGroup.createEntry(
                        creationDate: historyDate,
                        detached: true
                    ) as? Entry2 {
                        historyEntry.rawTitle = entry2.rawTitle
                        historyEntry.rawUserName = entry2.rawUserName
                        historyEntry.rawPassword = password
                        historyEntry.rawURL = entry2.rawURL
                        historyEntry.rawNotes = entry2.rawNotes
                        historyEntry.touch(.modifiedAt(historyDate))

                        entry2.history.append(historyEntry)
                    }
                }
            }
        } else {
            var historyText = "Password History:\n"
            for historyItem in history {
                if let password = historyItem.value {
                    let date = Date(timeIntervalSince1970: historyItem.time)
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    historyText += "- \(dateFormatter.string(from: date)): \(password)\n"
                }
            }
            if !entry.rawNotes.isEmpty {
                entry.rawNotes += "\n\n" + historyText
            } else {
                entry.rawNotes = historyText
            }
        }
    }

    private func addAttachment(
        _ documentAttributes: OnePasswordDocumentAttributes,
        to entry: Entry,
        parentGroup: Group,
        zipFileURL: URL,
        itemTitle: String
    ) throws {
        guard let fileName = documentAttributes.fileName,
              let documentId = documentAttributes.documentId else {
            return
        }

        let fileData: Data
        do {
            fileData = try extractFile(named: "\(documentId)__\(fileName)", from: zipFileURL)
        } catch {
            Diag.warning("Attachment file not found in archive: \(fileName) for item \(itemTitle), skipping")
            return
        }

        guard let attachment = parentGroup.database?.makeAttachment(
            name: fileName,
            data: ByteArray(data: fileData)
        ) else {
            Diag.error("Failed to create attachment for filename \(fileName) in item \(itemTitle)")
            throw ImportError.corruptedAttachmentData(itemName: itemTitle, attachmentName: fileName)
        }

        entry.attachments.append(attachment)
    }

    private func extractExportData(from zipURL: URL) throws -> String {
        let zipData = try Data(contentsOf: zipURL)
        let archive = try ZIPArchive(data: zipData)

        guard let exportDataEntry = archive.entries.first(where: { $0.fileName == "export.data" }) else {
            throw ImportError.invalidZIPFormat(reason: "export.data not found in archive")
        }

        let exportData = try archive.extractData(for: exportDataEntry)

        guard let exportString = String(data: exportData, encoding: .utf8) else {
            throw ImportError.parsingFailed(reason: "Could not convert export.data to UTF-8")
        }

        return exportString
    }

    private func extractFile(named fileName: String, from zipURL: URL) throws -> Data {
        let zipData = try Data(contentsOf: zipURL)
        let archive = try ZIPArchive(data: zipData)

        let filePath = "files/\(fileName)"
        guard let fileEntry = archive.entries.first(where: { $0.fileName == filePath }) else {
            throw ImportError.invalidZIPFormat(reason: "File \(fileName) not found in archive")
        }

        return try archive.extractData(for: fileEntry)
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        return self.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        return self.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
