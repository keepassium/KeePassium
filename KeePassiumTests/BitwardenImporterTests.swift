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

final class BitwardenImporterTests: XCTestCase {
    var importer: BitwardenImporter!
    var database: Database!

    override func setUp() {
        super.setUp()
        importer = BitwardenImporter()
        database = Database1()
    }

    override func tearDown() {
        importer = nil
        database = nil
        super.tearDown()
    }

    func testImportEmptyFile() throws {
        XCTAssertThrowsError(try importJSON("")) { error in
            guard let importError = error as? BitwardenImporter.ImportError else {
                XCTFail("Expected BitwardenImporter.ImportError")
                return
            }

            switch importError {
            case .emptyFile:
                break
            default:
                XCTFail("Expected emptyFile error but got \(importError)")
            }
        }
    }

    func testImportInvalidJSON() throws {
        XCTAssertThrowsError(try importJSON("{invalid-json")) { error in
            guard let importError = error as? BitwardenImporter.ImportError else {
                XCTFail("Expected BitwardenImporter.ImportError")
                return
            }

            switch importError {
            case .parsingFailed:
                break
            default:
                XCTFail("Expected parsingFailed error but got \(importError)")
            }
        }
    }

    func testImportEmptyVault() throws {
        let emptyVault = """
        {
            "items": []
        }
        """

        XCTAssertThrowsError(try importJSON(emptyVault)) { error in
            guard let importError = error as? BitwardenImporter.ImportError else {
                XCTFail("Expected BitwardenImporter.ImportError")
                return
            }

            switch importError {
            case .emptyFile:
                break
            default:
                XCTFail("Expected emptyFile error but got \(importError)")
            }
        }
    }

    func testImportEncryptedExport() throws {
        let encryptedVault = """
        {
            "encrypted": true,
            "items": [
                {
                    "type": 1,
                    "name": "Test",
                    "login": {}
                }
            ]
        }
        """

        XCTAssertThrowsError(try importJSON(encryptedVault)) { error in
            guard let importError = error as? BitwardenImporter.ImportError else {
                XCTFail("Expected BitwardenImporter.ImportError")
                return
            }

            switch importError {
            case .encryptedExport:
                break
            default:
                XCTFail("Expected encryptedExport error but got \(importError)")
            }
        }
    }

    func testImportBasicLoginEntry() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Test Login",
                    "notes": "This is a test note",
                    "favorite": false,
                    "login": {
                        "username": "testuser",
                        "password": "testpass",
                        "uris": [
                            {
                                "uri": "https://example.com"
                            }
                        ]
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "Test Login")
        XCTAssertEqual(entry.rawNotes, "This is a test note")
        XCTAssertEqual(entry.rawUserName, "testuser")
        XCTAssertEqual(entry.rawPassword, "testpass")
        XCTAssertEqual(entry.rawURL, "https://example.com")
    }

    func testImportLoginWithTOTP() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Login with TOTP",
                    "login": {
                        "username": "user",
                        "password": "pass",
                        "totp": "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "Login with TOTP")
        XCTAssertEqual(entry.rawUserName, "user")
        XCTAssertEqual(entry.rawPassword, "pass")
        XCTAssertEqual(entry.getField(EntryField.otp)?.value, "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        XCTAssertTrue(entry.getField(EntryField.otp)?.isProtected ?? false)
    }

    func testImportLoginWithInvalidTOTP() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Login with Invalid TOTP",
                    "login": {
                        "username": "user",
                        "password": "pass",
                        "totp": "not-a-valid-totp-uri"
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertNil(entry.getField(EntryField.otp))
        XCTAssertEqual(entry.getField("TOTP")?.value, "not-a-valid-totp-uri")
        XCTAssertTrue(entry.getField("TOTP")?.isProtected ?? false)
    }

    func testImportLoginWithMultipleURIs() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Login with Multiple URIs",
                    "login": {
                        "username": "user",
                        "password": "pass",
                        "uris": [
                            { "uri": "https://example.com" },
                            { "uri": "https://app.example.com" },
                            { "uri": "https://example.org" }
                        ]
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawURL, "https://example.com")
        XCTAssertEqual(entry.getField("URL 2")?.value, "https://app.example.com")
        XCTAssertEqual(entry.getField("URL 3")?.value, "https://example.org")
    }

    func testImportSecureNote() throws {
        let json = """
        {
            "items": [
                {
                    "type": 2,
                    "name": "My Secure Note",
                    "notes": "This is a secure note with sensitive information",
                    "secureNote": {
                        "type": 0
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "My Secure Note")
        XCTAssertEqual(entry.rawNotes, "This is a secure note with sensitive information")
        XCTAssertTrue(entry.rawUserName.isEmpty)
        XCTAssertTrue(entry.rawPassword.isEmpty)
        XCTAssertTrue(entry.rawURL.isEmpty)
    }

    func testImportCard() throws {
        let json = """
        {
            "items": [
                {
                    "type": 3,
                    "name": "My Credit Card",
                    "notes": "Personal card",
                    "card": {
                        "cardholderName": "John Doe",
                        "brand": "Visa",
                        "number": "4111111111111111",
                        "expMonth": "12",
                        "expYear": "2025",
                        "code": "123"
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "My Credit Card")
        XCTAssertEqual(entry.rawNotes, "Personal card")
        XCTAssertEqual(entry.getField("Cardholder Name")?.value, "John Doe")
        XCTAssertFalse(entry.getField("Cardholder Name")?.isProtected ?? true)
        XCTAssertEqual(entry.getField("Brand")?.value, "Visa")
        XCTAssertEqual(entry.getField("Number")?.value, "4111111111111111")
        XCTAssertTrue(entry.getField("Number")?.isProtected ?? false)
        XCTAssertEqual(entry.getField("Expiration Month")?.value, "12")
        XCTAssertEqual(entry.getField("Expiration Year")?.value, "2025")
        XCTAssertEqual(entry.getField("Security Code")?.value, "123")
        XCTAssertTrue(entry.getField("Security Code")?.isProtected ?? false)
    }

    func testImportIdentity() throws {
        let json = """
        {
            "items": [
                {
                    "type": 4,
                    "name": "My Identity",
                    "notes": "Personal info",
                    "identity": {
                        "title": "Mr.",
                        "firstName": "John",
                        "middleName": "Q",
                        "lastName": "Doe",
                        "username": "johndoe",
                        "company": "Example Corp",
                        "email": "john@example.com",
                        "phone": "+1234567890",
                        "address1": "123 Main St",
                        "address2": "Apt 4B",
                        "city": "New York",
                        "state": "NY",
                        "postalCode": "10001",
                        "country": "USA",
                        "ssn": "123-45-6789",
                        "passportNumber": "ABC123456",
                        "licenseNumber": "DL123456"
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "My Identity")
        XCTAssertEqual(entry.rawNotes, "Personal info")
        XCTAssertEqual(entry.rawUserName, "johndoe")
        XCTAssertEqual(entry.getField("Name Title")?.value, "Mr.")
        XCTAssertEqual(entry.getField("First Name")?.value, "John")
        XCTAssertEqual(entry.getField("Middle Name")?.value, "Q")
        XCTAssertEqual(entry.getField("Last Name")?.value, "Doe")
        XCTAssertEqual(entry.getField("Company")?.value, "Example Corp")
        XCTAssertEqual(entry.getField("Email")?.value, "john@example.com")
        XCTAssertEqual(entry.getField("Phone")?.value, "+1234567890")
        XCTAssertEqual(entry.getField("Address 1")?.value, "123 Main St")
        XCTAssertEqual(entry.getField("Address 2")?.value, "Apt 4B")
        XCTAssertEqual(entry.getField("City")?.value, "New York")
        XCTAssertEqual(entry.getField("State")?.value, "NY")
        XCTAssertEqual(entry.getField("Postal Code")?.value, "10001")
        XCTAssertEqual(entry.getField("Country")?.value, "USA")
        XCTAssertEqual(entry.getField("SSN")?.value, "123-45-6789")
        XCTAssertTrue(entry.getField("SSN")?.isProtected ?? false)
        XCTAssertEqual(entry.getField("Passport Number")?.value, "ABC123456")
        XCTAssertTrue(entry.getField("Passport Number")?.isProtected ?? false)
        XCTAssertEqual(entry.getField("License Number")?.value, "DL123456")
        XCTAssertTrue(entry.getField("License Number")?.isProtected ?? false)
    }

    func testImportCustomFields() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Entry with Custom Fields",
                    "login": {
                        "username": "user",
                        "password": "pass"
                    },
                    "fields": [
                        {
                            "name": "Text Field",
                            "value": "visible text",
                            "type": 0
                        },
                        {
                            "name": "Hidden Field",
                            "value": "secret value",
                            "type": 1
                        },
                        {
                            "name": "Boolean Field",
                            "value": "true",
                            "type": 2
                        }
                    ]
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.getField("Text Field")?.value, "visible text")
        XCTAssertFalse(entry.getField("Text Field")?.isProtected ?? true)
        XCTAssertEqual(entry.getField("Hidden Field")?.value, "secret value")
        XCTAssertTrue(entry.getField("Hidden Field")?.isProtected ?? false)
        XCTAssertEqual(entry.getField("Boolean Field")?.value, "true")
        XCTAssertFalse(entry.getField("Boolean Field")?.isProtected ?? true)
    }

    func testImportPasswordHistory() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Entry with Password History",
                    "login": {
                        "username": "user",
                        "password": "currentpass"
                    },
                    "passwordHistory": [
                        {
                            "lastUsedDate": "2023-01-15T10:30:00.000Z",
                            "password": "oldpass1"
                        },
                        {
                            "lastUsedDate": "2023-06-20T14:45:00.000Z",
                            "password": "oldpass2"
                        }
                    ]
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawPassword, "currentpass")
        XCTAssertTrue(entry.rawNotes.contains("Password History:"))
        XCTAssertTrue(entry.rawNotes.contains("2023-01-15T10:30:00.000Z: oldpass1"))
        XCTAssertTrue(entry.rawNotes.contains("2023-06-20T14:45:00.000Z: oldpass2"))
    }

    func testImportFavoriteEntry() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Favorite Entry",
                    "favorite": true,
                    "login": {
                        "username": "user",
                        "password": "pass"
                    }
                },
                {
                    "type": 1,
                    "name": "Regular Entry",
                    "favorite": false,
                    "login": {}
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 2)
        let favoriteEntry = entries.first { $0.rawTitle == "Favorite Entry" }
        XCTAssertNotNil(favoriteEntry)
        let regularEntry = entries.first { $0.rawTitle == "Regular Entry" }
        XCTAssertNotNil(regularEntry)
    }

    func testImportFoldersAsGroups() throws {
        let json = """
        {
            "folders": [
                {
                    "id": "folder1-uuid",
                    "name": "Work"
                },
                {
                    "id": "folder2-uuid",
                    "name": "Personal"
                }
            ],
            "items": [
                {
                    "type": 1,
                    "name": "Work Login",
                    "folderId": "folder1-uuid",
                    "login": {
                        "username": "workuser",
                        "password": "workpass"
                    }
                },
                {
                    "type": 1,
                    "name": "Personal Login",
                    "folderId": "folder2-uuid",
                    "login": {
                        "username": "personaluser",
                        "password": "personalpass"
                    }
                },
                {
                    "type": 1,
                    "name": "Another Work Login",
                    "folderId": "folder1-uuid",
                    "login": {}
                },
                {
                    "type": 1,
                    "name": "No Folder Entry",
                    "login": {}
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertEqual(groups.count, 2)

        let workGroup = groups.first { $0.name == "Work" }
        XCTAssertNotNil(workGroup)
        XCTAssertEqual(workGroup?.entries.count, 2)

        let personalGroup = groups.first { $0.name == "Personal" }
        XCTAssertNotNil(personalGroup)
        XCTAssertEqual(personalGroup?.entries.count, 1)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.rawTitle, "No Folder Entry")
    }

    func testImportMultipleEntries() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Entry 1",
                    "login": {
                        "username": "user1",
                        "password": "pass1"
                    }
                },
                {
                    "type": 2,
                    "name": "Entry 2",
                    "notes": "Note 2",
                    "secureNote": {}
                },
                {
                    "type": 1,
                    "name": "Entry 3",
                    "login": {
                        "username": "user3",
                        "password": "pass3"
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].rawTitle, "Entry 1")
        XCTAssertEqual(entries[0].rawUserName, "user1")
        XCTAssertEqual(entries[1].rawTitle, "Entry 2")
        XCTAssertEqual(entries[1].rawNotes, "Note 2")
        XCTAssertEqual(entries[2].rawTitle, "Entry 3")
        XCTAssertEqual(entries[2].rawUserName, "user3")
    }

    func testImportWithEmptyFields() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Entry with Empty Fields",
                    "login": {
                        "username": "",
                        "password": "",
                        "uris": []
                    },
                    "fields": [
                        {
                            "name": "Empty Custom Field",
                            "value": "",
                            "type": 0
                        }
                    ]
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "Entry with Empty Fields")
        XCTAssertEqual(entry.rawUserName, "")
        XCTAssertEqual(entry.rawPassword, "")
        XCTAssertEqual(entry.rawURL, "")
        XCTAssertNil(entry.getField("Empty Custom Field"))
    }

    func testImportWithSpecialCharacters() throws {
        let json = """
        {
            "items": [
                {
                    "type": 1,
                    "name": "Entry with 特殊字符 & émojis 🔐",
                    "notes": "Notes with special chars: <>&\\"'\\n\\t",
                    "login": {
                        "username": "user@domain.com",
                        "password": "p@$$w0rd!#%^&*()",
                        "uris": [
                            {
                                "uri": "https://example.com/path?query=value&other=data"
                            }
                        ]
                    }
                }
            ]
        }
        """

        let (entries, groups) = try importJSON(json)
        XCTAssertTrue(groups.isEmpty)

        XCTAssertEqual(entries.count, 1)
        let entry = entries[0]
        XCTAssertEqual(entry.rawTitle, "Entry with 特殊字符 & émojis 🔐")
        XCTAssertEqual(entry.rawUserName, "user@domain.com")
        XCTAssertEqual(entry.rawPassword, "p@$$w0rd!#%^&*()")
        XCTAssertEqual(entry.rawURL, "https://example.com/path?query=value&other=data")
        XCTAssertTrue(entry.rawNotes.contains("<>&\"'"))
    }

    func testImportComplexScenario() throws {
        let json = """
        {
            "folders": [
                {
                    "id": "work-folder",
                    "name": "Work Accounts"
                }
            ],
            "items": [
                {
                    "type": 1,
                    "name": "Main Work Account",
                    "notes": "Primary work credentials",
                    "favorite": true,
                    "folderId": "work-folder",
                    "login": {
                        "username": "work.user@company.com",
                        "password": "SecureP@ss123",
                        "uris": [
                            { "uri": "https://company.com" },
                            { "uri": "https://app.company.com" }
                        ],
                        "totp": "otpauth://totp/Company:work.user@company.com?secret=JBSWY3DPEHPK3PXP&issuer=Company"
                    },
                    "fields": [
                        {
                            "name": "Security Question",
                            "value": "What is your pet's name?",
                            "type": 0
                        },
                        {
                            "name": "Security Answer",
                            "value": "Fluffy",
                            "type": 1
                        }
                    ],
                    "passwordHistory": [
                        {
                            "lastUsedDate": "2024-01-15T10:00:00.000Z",
                            "password": "OldP@ss456"
                        }
                    ]
                }
            ]
        }
        """

        let (_, groups) = try importJSON(json)
        XCTAssertEqual(groups.count, 1)

        let workGroup = groups.first { $0.name == "Work Accounts" }
        XCTAssertNotNil(workGroup)
        XCTAssertEqual(workGroup?.entries.count, 1)

        let entry = workGroup?.entries.first
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.rawTitle, "Main Work Account")
        XCTAssertEqual(entry?.rawUserName, "work.user@company.com")
        XCTAssertEqual(entry?.rawPassword, "SecureP@ss123")
        XCTAssertEqual(entry?.rawURL, "https://company.com")
        XCTAssertEqual(entry?.getField("URL 2")?.value, "https://app.company.com")
        XCTAssertNotNil(entry?.getField(EntryField.otp))
        XCTAssertEqual(entry?.getField("Security Question")?.value, "What is your pet's name?")
        XCTAssertFalse(entry?.getField("Security Question")?.isProtected ?? true)
        XCTAssertEqual(entry?.getField("Security Answer")?.value, "Fluffy")
        XCTAssertTrue(entry?.getField("Security Answer")?.isProtected ?? false)
        XCTAssertTrue(entry?.rawNotes.contains("Password History:") ?? false)
        XCTAssertTrue(entry?.rawNotes.contains("OldP@ss456") ?? false)
    }
}

extension BitwardenImporterTests {
    private func importJSON(_ content: String) throws -> ([Entry], [Group]) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        let root = Group1(database: database)
        database.root = root
        return try importer.importFromJSON(fileURL: tempURL, group: database.root!)
    }
}

extension BitwardenImporter.ImportError: @retroactive Equatable {}
extension BitwardenImporter.ImportError: DumpEquatable { }
