//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
@testable import KeePassium
@testable import KeePassiumLib
import XCTest

final class OnePasswordImporterTests: XCTestCase {
    var importer: OnePasswordImporter!
    var database: Database!

    private let crc32Table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                crc = (crc & 1 == 1) ? ((crc >> 1) ^ 0xedb88320) : (crc >> 1)
            }
            return crc
        }
    }()

    override func setUp() {
        super.setUp()
        importer = OnePasswordImporter()
        database = Database1()
    }

    override func tearDown() {
        importer = nil
        database = nil
        super.tearDown()
    }

    func testImportBasicEntry() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {
                            "title": "Test Entry",
                            "url": "https://example.com",
                            "tags": ["work", "important"]
                        },
                        "details": {
                            "loginFields": [
                                {
                                    "designation": "username",
                                    "value": "testuser"
                                },
                                {
                                    "designation": "password",
                                    "value": "testpass123"
                                }
                            ],
                            "notesPlain": "These are my notes"
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, groups) = try import1PUX(json)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertEqual(entries.count, 1)

        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "Test Entry")
        XCTAssertEqual(entry.rawUserName, "testuser")
        XCTAssertEqual(entry.rawPassword, "testpass123")
        XCTAssertEqual(entry.rawURL, "https://example.com")
        XCTAssertEqual(entry.rawNotes, "These are my notes")
        XCTAssertEqual(entry.tags, ["work", "important"])
    }

    func testImportMultipleEntries() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [
                        {
                            "uuid": "uuid1",
                            "state": "active",
                            "overview": {
                                "title": "Entry 1"
                            },
                            "details": {
                                "loginFields": [
                                    {"designation": "username", "value": "user1"}
                                ]
                            }
                        },
                        {
                            "uuid": "uuid2",
                            "state": "active",
                            "overview": {
                                "title": "Entry 2"
                            },
                            "details": {
                                "loginFields": [
                                    {"designation": "username", "value": "user2"}
                                ]
                            }
                        }
                    ]
                }]
            }]
        }
        """

        let (entries, groups) = try import1PUX(json)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].rawTitle, "Entry 1")
        XCTAssertEqual(entries[0].rawUserName, "user1")
        XCTAssertEqual(entries[1].rawTitle, "Entry 2")
        XCTAssertEqual(entries[1].rawUserName, "user2")
    }

    func testImportWithMultipleURLs() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {
                            "title": "Entry with URLs",
                            "urls": [
                                {"label": "website", "url": "https://example.com"},
                                {"label": "admin", "url": "https://admin.example.com"}
                            ]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].rawURL, "https://example.com")
    }

    func testImportIncludesArchivedItems() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [
                        {
                            "uuid": "active-uuid",
                            "state": "active",
                            "overview": {"title": "Active Entry"}
                        },
                        {
                            "uuid": "archived-uuid",
                            "state": "archived",
                            "overview": {"title": "Archived Entry"}
                        }
                    ]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].rawTitle, "Active Entry")
        XCTAssertEqual(entries[1].rawTitle, "Archived Entry")
    }

    func testImportWithTOTP() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with TOTP"},
                        "details": {
                            "sections": [{
                                "fields": [{
                                    "title": "one-time password",
                                    "value": "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example",
                                    "type": "T"
                                }]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let otpField = entries[0].fields.first { $0.name == EntryField.otp }
        XCTAssertNotNil(otpField)
        XCTAssertEqual(
            otpField?.value,
            "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        )
        XCTAssertTrue(otpField?.isProtected ?? false)
    }

    func testImportWithCustomFields() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Custom Fields"},
                        "details": {
                            "sections": [{
                                "title": "Additional Info",
                                "fields": [
                                    {
                                        "title": "Security Question",
                                        "value": "Mother's maiden name",
                                        "type": "T"
                                    },
                                    {
                                        "title": "Secret Key",
                                        "value": "super-secret-key",
                                        "type": "P"
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let securityQuestion = entries[0].getField("Security Question")
        XCTAssertNotNil(securityQuestion)
        XCTAssertEqual(securityQuestion?.value, "Mother's maiden name")
        XCTAssertFalse(securityQuestion?.isProtected ?? true)

        let secretKey = entries[0].getField("Secret Key")
        XCTAssertNotNil(secretKey)
        XCTAssertEqual(secretKey?.value, "super-secret-key")
        XCTAssertTrue(secretKey?.isProtected ?? false)
    }

    func testImportWithDates() throws {
        let creationTimestamp: Double = 1557753600
        let modificationTimestamp: Double = 1642690800

        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "createdAt": \(creationTimestamp),
                        "updatedAt": \(modificationTimestamp),
                        "overview": {"title": "Entry with Dates"}
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let entry = entries[0]
        XCTAssertEqual(entry.creationTime, Date(timeIntervalSince1970: creationTimestamp))
        XCTAssertEqual(entry.lastModificationTime, Date(timeIntervalSince1970: modificationTimestamp))
    }

    func testImportPasswordHistory() throws {
        let timestamp1: Double = 1557753600
        let timestamp2: Double = 1642690800

        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with History"},
                        "details": {
                            "loginFields": [
                                {"designation": "password", "value": "currentpassword"}
                            ],
                            "passwordHistory": [
                                {"value": "oldpassword1", "time": \(timestamp1)},
                                {"value": "oldpassword2", "time": \(timestamp2)}
                            ]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let entry = entries[0]
        XCTAssertEqual(entry.rawPassword, "currentpassword")
        XCTAssertTrue(entry.rawNotes.contains("Password History:"))
        XCTAssertTrue(entry.rawNotes.contains("oldpassword1"))
        XCTAssertTrue(entry.rawNotes.contains("oldpassword2"))
    }

    func testImportEmptyFileError() {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": []
                }]
            }]
        }
        """

        XCTAssertThrowsError(try import1PUX(json)) { error in
            XCTAssertEqual(error as? OnePasswordImporter.ImportError, .emptyFile)
        }
    }

    func testImportInvalidJSON() {
        let json = "{invalid-json"

        XCTAssertThrowsError(try import1PUX(json)) { error in
            guard case let .parsingFailed(reason) = error as? OnePasswordImporter.ImportError else {
                XCTFail("Expected parsingFailed error")
                return
            }
            XCTAssertFalse(reason.isEmpty)
        }
    }

    func testImportMultipleVaultsFlat() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [
                    {
                        "items": [{
                            "uuid": "vault1-item",
                            "state": "active",
                            "overview": {"title": "Vault 1 Entry"}
                        }]
                    },
                    {
                        "items": [{
                            "uuid": "vault2-item",
                            "state": "active",
                            "overview": {"title": "Vault 2 Entry"}
                        }]
                    }
                ]
            }]
        }
        """

        let (entries, groups) = try import1PUX(json)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].rawTitle, "Vault 1 Entry")
        XCTAssertEqual(entries[1].rawTitle, "Vault 2 Entry")
    }

    func testImportFieldsWithStringWrapper() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Driver License"},
                        "details": {
                            "sections": [{
                                "title": "",
                                "fields": [
                                    {
                                        "title": "vollständiger name",
                                        "id": "fullname",
                                        "value": {"string": "John Doe"}
                                    },
                                    {
                                        "title": "nummer",
                                        "id": "number",
                                        "value": {"string": "B071231UN81"}
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let fullName = entries[0].getField("vollständiger name")
        XCTAssertNotNil(fullName, "Field with string-wrapped value should be imported")
        XCTAssertEqual(fullName?.value, "John Doe")

        let number = entries[0].getField("nummer")
        XCTAssertNotNil(number, "Field with string-wrapped value should be imported")
        XCTAssertEqual(number?.value, "B071231UN81")
    }

    func testImportFieldsWithDateWrapper() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Date Field"},
                        "details": {
                            "sections": [{
                                "title": "",
                                "fields": [
                                    {
                                        "title": "geburtsdatum",
                                        "id": "birthdate",
                                        "value": {"date": 315532800}
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let dateField = entries[0].getField("geburtsdatum")
        XCTAssertNotNil(dateField, "Field with date-wrapped value should be imported")
        XCTAssertFalse(dateField?.value.isEmpty ?? true)
    }

    func testImportFieldsWithNullMonthYear() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Null MonthYear"},
                        "details": {
                            "sections": [{
                                "title": "",
                                "fields": [
                                    {
                                        "title": "gültigkeitsdatum",
                                        "id": "expiry_date",
                                        "value": {"monthYear": null}
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)
        let expiryField = entries[0].getField("gültigkeitsdatum")
        XCTAssertNil(expiryField, "Field with null value should not be imported")
    }

    func testImportFieldsWithConcealedWrapper() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Concealed"},
                        "details": {
                            "sections": [{
                                "title": "",
                                "fields": [
                                    {
                                        "title": "secret pin",
                                        "id": "pin",
                                        "value": {"concealed": "1234"},
                                        "type": "P"
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let pin = entries[0].getField("secret pin")
        XCTAssertNotNil(pin, "Field with concealed-wrapped value should be imported")
        XCTAssertEqual(pin?.value, "1234")
        XCTAssertTrue(pin?.isProtected ?? false)
    }

    func testImportFieldsWithTOTPWrapper() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with TOTP in wrapper"},
                        "details": {
                            "sections": [{
                                "title": "",
                                "fields": [
                                    {
                                        "title": "one-time password",
                                        "id": "otp",
                                        "value": {"totp": "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"}
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)

        let otpField = entries[0].fields.first { $0.name == EntryField.otp }
        XCTAssertNotNil(otpField)
        XCTAssertEqual(
            otpField?.value,
            "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        )
    }

    func testImportWithInlineFileAttachment() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Inline Attachment"},
                        "details": {
                            "sections": [{
                                "title": "Abschnitt",
                                "fields": [
                                    {
                                        "title": "",
                                        "id": "field1",
                                        "value": {
                                            "file": {
                                                "fileName": "photo.jpg",
                                                "documentId": "abc123",
                                                "decryptedSize": 1024
                                            }
                                        }
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let fileContent = Data(repeating: 0xFF, count: 1024)
        let (entries, _) = try import1PUXWithFiles(json, files: [("files/abc123__photo.jpg", fileContent)])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].attachments.count, 1)
        guard entries[0].attachments.count == 1 else { return }
        XCTAssertEqual(entries[0].attachments[0].name, "photo.jpg")
    }

    func testImportWithMultipleInlineFileAttachments() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Multiple Attachments"},
                        "details": {
                            "sections": [{
                                "title": "Abschnitt",
                                "fields": [
                                    {
                                        "title": "",
                                        "id": "field1",
                                        "value": {
                                            "file": {
                                                "fileName": "photo1.jpg",
                                                "documentId": "doc1",
                                                "decryptedSize": 100
                                            }
                                        }
                                    },
                                    {
                                        "title": "",
                                        "id": "field2",
                                        "value": {
                                            "file": {
                                                "fileName": "photo2.jpg",
                                                "documentId": "doc2",
                                                "decryptedSize": 200
                                            }
                                        }
                                    }
                                ]
                            }]
                        }
                    }]
                }]
            }]
        }
        """

        let file1 = Data(repeating: 0xAA, count: 100)
        let file2 = Data(repeating: 0xBB, count: 200)
        let (entries, _) = try import1PUXWithFiles(json, files: [
            ("files/doc1__photo1.jpg", file1),
            ("files/doc2__photo2.jpg", file2),
        ])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].attachments.count, 2)
        guard entries[0].attachments.count == 2 else { return }
        XCTAssertEqual(entries[0].attachments[0].name, "photo1.jpg")
        XCTAssertEqual(entries[0].attachments[1].name, "photo2.jpg")
    }

    func testImportWithEmptyFields() throws {
        let json = """
        {
            "accounts": [{
                "vaults": [{
                    "items": [{
                        "uuid": "test-uuid",
                        "state": "active",
                        "overview": {"title": "Entry with Empty Fields"},
                        "details": {
                            "loginFields": [
                                {"designation": "username", "value": ""},
                                {"designation": "password", "value": null}
                            ]
                        }
                    }]
                }]
            }]
        }
        """

        let (entries, _) = try import1PUX(json)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].rawUserName, "")
        XCTAssertEqual(entries[0].rawPassword, "")
    }

    private func import1PUX(_ jsonContent: String) throws -> ([Entry], [Group]) {
        return try import1PUXWithFiles(jsonContent, files: [])
    }

    private func import1PUXWithFiles(
        _ jsonContent: String,
        files: [(name: String, data: Data)]
    ) throws -> ([Entry], [Group]) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        var zipFiles: [(name: String, data: Data)] = [
            ("export.data", jsonContent.data(using: .utf8)!)
        ]
        zipFiles.append(contentsOf: files)

        let zipURL = tempDir.appendingPathComponent("test.1pux")
        try createZipArchive(at: zipURL, containing: zipFiles)

        let root = Group1(database: database)
        database.root = root
        return try importer.importFrom1PUX(fileURL: zipURL, group: database.root!)
    }

    private func createZipArchive(at url: URL, containing files: [(name: String, data: Data)]) throws {
        var zipData = Data()

        struct LocalFileHeader {
            var offset: UInt32 = 0
            var compressedSize: UInt32 = 0
            var uncompressedSize: UInt32 = 0
            var crc32: UInt32 = 0
            var fileName: String = ""
        }

        var headers: [LocalFileHeader] = []

        for (fileName, fileData) in files {
            let currentOffset = UInt32(zipData.count)
            var header = LocalFileHeader()
            header.offset = currentOffset
            header.fileName = fileName
            header.uncompressedSize = UInt32(fileData.count)
            header.compressedSize = UInt32(fileData.count)
            header.crc32 = crc32(fileData)

            zipData.append(contentsOf: [0x50, 0x4b, 0x03, 0x04])
            zipData.append(contentsOf: [0x14, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: withUnsafeBytes(of: header.crc32.littleEndian) { Array($0) })
            zipData.append(contentsOf: withUnsafeBytes(of: header.compressedSize.littleEndian) { Array($0) })
            zipData.append(contentsOf: withUnsafeBytes(of: header.uncompressedSize.littleEndian) { Array($0) })
            let fileNameData = fileName.data(using: .utf8)!
            zipData.append(contentsOf: withUnsafeBytes(of: UInt16(fileNameData.count).littleEndian) { Array($0) })
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(fileNameData)
            zipData.append(fileData)

            headers.append(header)
        }

        let centralDirOffset = UInt32(zipData.count)

        for header in headers {
            zipData.append(contentsOf: [0x50, 0x4b, 0x01, 0x02])
            zipData.append(contentsOf: [0x14, 0x00])
            zipData.append(contentsOf: [0x14, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: withUnsafeBytes(of: header.crc32.littleEndian) { Array($0) })
            zipData.append(contentsOf: withUnsafeBytes(of: header.compressedSize.littleEndian) { Array($0) })
            zipData.append(contentsOf: withUnsafeBytes(of: header.uncompressedSize.littleEndian) { Array($0) })
            let fileNameData = header.fileName.data(using: .utf8)!
            zipData.append(contentsOf: withUnsafeBytes(of: UInt16(fileNameData.count).littleEndian) { Array($0) })
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00])
            zipData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            zipData.append(contentsOf: withUnsafeBytes(of: header.offset.littleEndian) { Array($0) })
            zipData.append(fileNameData)
        }

        let centralDirSize = UInt32(zipData.count) - centralDirOffset

        zipData.append(contentsOf: [0x50, 0x4b, 0x05, 0x06])
        zipData.append(contentsOf: [0x00, 0x00])
        zipData.append(contentsOf: [0x00, 0x00])
        zipData.append(contentsOf: withUnsafeBytes(of: UInt16(headers.count).littleEndian) { Array($0) })
        zipData.append(contentsOf: withUnsafeBytes(of: UInt16(headers.count).littleEndian) { Array($0) })
        zipData.append(contentsOf: withUnsafeBytes(of: centralDirSize.littleEndian) { Array($0) })
        zipData.append(contentsOf: withUnsafeBytes(of: centralDirOffset.littleEndian) { Array($0) })
        zipData.append(contentsOf: [0x00, 0x00])

        try zipData.write(to: url)
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return ~crc
    }
}

extension OnePasswordImporter.ImportError: @retroactive Equatable {
    public static func == (lhs: OnePasswordImporter.ImportError, rhs: OnePasswordImporter.ImportError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyFile, .emptyFile):
            return true
        case let (.invalidZIPFormat(reason1), .invalidZIPFormat(reason2)):
            return reason1 == reason2
        case let (.parsingFailed(reason1), .parsingFailed(reason2)):
            return reason1 == reason2
        case let (.corruptedAttachmentData(item1, attach1), .corruptedAttachmentData(item2, attach2)):
            return item1 == item2 && attach1 == attach2
        default:
            return false
        }
    }
}

extension OnePasswordImporter.ImportError: DumpEquatable { }
