//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

public class BitwardenImporter {
    private struct BitwardenVault: Decodable {
        let encrypted: Bool?
        let folders: [BitwardenFolder]?
        let items: [BitwardenItem]
    }

    private struct BitwardenFolder: Decodable {
        let id: String
        let name: String
    }

    private struct BitwardenItem: Decodable {
        let id: String?
        let organizationId: String?
        let folderId: String?
        let type: Int
        let reprompt: Int?
        let name: String
        let notes: String?
        let favorite: Bool?
        let fields: [BitwardenField]?
        let login: BitwardenLogin?
        let secureNote: BitwardenSecureNote?
        let card: BitwardenCard?
        let identity: BitwardenIdentity?
        let passwordHistory: [BitwardenPasswordHistory]?
        let collectionIds: [String]?
    }

    private struct BitwardenLogin: Decodable {
        let uris: [BitwardenURI]?
        let username: String?
        let password: String?
        let totp: String?
    }

    private struct BitwardenURI: Decodable {
        let match: Int?
        let uri: String
    }

    private struct BitwardenField: Decodable {
        let name: String
        let value: String?
        let type: Int
        let linkedId: Int?
    }

    private struct BitwardenSecureNote: Decodable {
        let type: Int?
    }

    private struct BitwardenCard: Decodable {
        let cardholderName: String?
        let brand: String?
        let number: String?
        let expMonth: String?
        let expYear: String?
        let code: String?
    }

    private struct BitwardenIdentity: Decodable {
        let title: String?
        let firstName: String?
        let middleName: String?
        let lastName: String?
        let address1: String?
        let address2: String?
        let address3: String?
        let city: String?
        let state: String?
        let postalCode: String?
        let country: String?
        let company: String?
        let email: String?
        let phone: String?
        let ssn: String?
        let username: String?
        let passportNumber: String?
        let licenseNumber: String?
    }

    private struct BitwardenPasswordHistory: Decodable {
        let lastUsedDate: String?
        let password: String
    }

    private enum ItemType: Int {
        case login = 1
        case secureNote = 2
        case card = 3
        case identity = 4
    }

    private enum CustomFieldType: Int {
        case text = 0
        case hidden = 1
        case boolean = 2
        case linked = 3
    }

    public enum ImportError: LocalizedError {
        case emptyFile
        case encryptedExport
        case parsingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return LString.Error.importEmptyIncomingFile
            case .encryptedExport:
                return LString.Error.importBitwardenEncryptedExport
            case let .parsingFailed(details):
                let message = [LString.Error.importJSONParsingFailed, details].joined(separator: "\n\n")
                return message
            }
        }
    }

    private static let dateFormatter = ISO8601DateFormatter()

    public init() {}

    public func importFromJSON(fileURL: URL, group: Group) throws -> ([Entry], [Group]) {
        let jsonData = try Data(contentsOf: fileURL)

        guard !jsonData.isEmpty else {
            Diag.error("Incoming JSON file is empty")
            throw ImportError.emptyFile
        }

        do {
            let decoder = JSONDecoder()
            let vault = try decoder.decode(BitwardenVault.self, from: jsonData)

            if vault.encrypted == true {
                Diag.error("Bitwarden export is encrypted")
                throw ImportError.encryptedExport
            }

            guard !vault.items.isEmpty else {
                Diag.error("No items found in the Bitwarden vault")
                throw ImportError.emptyFile
            }

            var folders: [String: String] = [:]
            if let bitwardenFolders = vault.folders {
                for folder in bitwardenFolders {
                    folders[folder.id] = folder.name
                }
            }

            var groups: [String: Group] = [:]
            var entries: [Entry] = []

            for item in vault.items {
                let parentGroup: Group
                let hasFolder: Bool
                if let folderId = item.folderId,
                   let folderName = folders[folderId],
                   !folderName.isEmpty {
                    if let existingGroup = groups[folderName] {
                        parentGroup = existingGroup
                    } else {
                        let subgroup = group.createGroup(detached: true)
                        subgroup.name = folderName
                        groups[folderName] = subgroup
                        parentGroup = subgroup
                    }
                    hasFolder = true
                } else {
                    parentGroup = group
                    hasFolder = false
                }

                let entry: Entry = parentGroup.createEntry(detached: !hasFolder)

                entry.rawTitle = item.name
                entry.rawNotes = item.notes ?? ""

                guard let itemType = ItemType(rawValue: item.type) else {
                    Diag.warning("Unknown Bitwarden item type: \(item.type)")
                    continue
                }

                switch itemType {
                case .login:
                    processLoginItem(item: item, entry: entry)

                case .secureNote:
                    break

                case .card:
                    processCardItem(item: item, entry: entry)

                case .identity:
                    processIdentityItem(item: item, entry: entry)
                }

                if let customFields = item.fields {
                    for field in customFields {
                        guard let value = field.value, !value.isEmpty else { continue }

                        let isProtected = field.type == CustomFieldType.hidden.rawValue
                        entry.setField(name: field.name, value: value, isProtected: isProtected)
                    }
                }

                if let passwordHistory = item.passwordHistory, !passwordHistory.isEmpty {
                    if let entry2 = entry as? Entry2 {
                        for historyItem in passwordHistory {
                            let historyDate: Date
                            if let lastUsedDateString = historyItem.lastUsedDate,
                               let lastUsedDate = Self.dateFormatter.date(from: lastUsedDateString) {
                                historyDate = lastUsedDate
                            } else {
                                historyDate = Date()
                            }

                            if let historyEntry = parentGroup.createEntry(
                                creationDate: historyDate,
                                detached: true
                            ) as? Entry2 {
                                historyEntry.rawTitle = entry2.rawTitle
                                historyEntry.rawUserName = entry2.rawUserName
                                historyEntry.rawPassword = historyItem.password
                                historyEntry.rawURL = entry2.rawURL
                                historyEntry.rawNotes = entry2.rawNotes
                                historyEntry.touch(.modifiedAt(historyDate))

                                entry2.history.append(historyEntry)
                            }
                        }
                    } else {
                        var historyText = "Password History:\n"
                        for historyItem in passwordHistory {
                            let date = historyItem.lastUsedDate ?? "Unknown date"
                            historyText += "- \(date): \(historyItem.password)\n"
                        }
                        if !entry.rawNotes.isEmpty {
                            entry.rawNotes += "\n\n" + historyText
                        } else {
                            entry.rawNotes = historyText
                        }
                    }
                }

                entry.touch(.modified)

                if !hasFolder {
                    entries.append(entry)
                }
            }

            return (entries, Array(groups.values))
        } catch let decodingError as DecodingError {
            Diag.error("Failed to decode Bitwarden JSON: \(decodingError)")
            throw ImportError.parsingFailed(decodingError.localizedDescription)
        } catch {
            Diag.error("Unexpected error during Bitwarden import: \(error)")
            throw error
        }
    }

    private func processLoginItem(item: BitwardenItem, entry: Entry) {
        guard let login = item.login else { return }

        entry.rawUserName = login.username ?? ""
        entry.rawPassword = login.password ?? ""

        if let uris = login.uris, !uris.isEmpty {
            entry.rawURL = uris[0].uri

            if uris.count > 1 {
                for (index, uri) in uris.enumerated().dropFirst() {
                    entry.setField(name: "URL \(index + 1)", value: uri.uri, isProtected: false)
                }
            }
        }

        if let totp = login.totp, !totp.isEmpty {
            if TOTPGeneratorFactory.isValidURI(totp) {
                entry.setField(name: EntryField.otp, value: totp, isProtected: true)
            } else {
                entry.setField(name: "TOTP", value: totp, isProtected: true)
            }
        }
    }

    private func processCardItem(item: BitwardenItem, entry: Entry) {
        guard let card = item.card else { return }

        if let cardholderName = card.cardholderName, !cardholderName.isEmpty {
            entry.setField(name: "Cardholder Name", value: cardholderName, isProtected: false)
        }
        if let brand = card.brand, !brand.isEmpty {
            entry.setField(name: "Brand", value: brand, isProtected: false)
        }
        if let number = card.number, !number.isEmpty {
            entry.setField(name: "Number", value: number, isProtected: true)
        }
        if let expMonth = card.expMonth, !expMonth.isEmpty {
            entry.setField(name: "Expiration Month", value: expMonth, isProtected: false)
        }
        if let expYear = card.expYear, !expYear.isEmpty {
            entry.setField(name: "Expiration Year", value: expYear, isProtected: false)
        }
        if let code = card.code, !code.isEmpty {
            entry.setField(name: "Security Code", value: code, isProtected: true)
        }
    }

    private func processIdentityItem(item: BitwardenItem, entry: Entry) {
        guard let identity = item.identity else { return }

        if let title = identity.title, !title.isEmpty {
            entry.setField(name: "Name Title", value: title, isProtected: false)
        }
        if let firstName = identity.firstName, !firstName.isEmpty {
            entry.setField(name: "First Name", value: firstName, isProtected: false)
        }
        if let middleName = identity.middleName, !middleName.isEmpty {
            entry.setField(name: "Middle Name", value: middleName, isProtected: false)
        }
        if let lastName = identity.lastName, !lastName.isEmpty {
            entry.setField(name: "Last Name", value: lastName, isProtected: false)
        }
        if let company = identity.company, !company.isEmpty {
            entry.setField(name: "Company", value: company, isProtected: false)
        }
        if let email = identity.email, !email.isEmpty {
            entry.setField(name: "Email", value: email, isProtected: false)
        }
        if let phone = identity.phone, !phone.isEmpty {
            entry.setField(name: "Phone", value: phone, isProtected: false)
        }
        if let address1 = identity.address1, !address1.isEmpty {
            entry.setField(name: "Address 1", value: address1, isProtected: false)
        }
        if let address2 = identity.address2, !address2.isEmpty {
            entry.setField(name: "Address 2", value: address2, isProtected: false)
        }
        if let address3 = identity.address3, !address3.isEmpty {
            entry.setField(name: "Address 3", value: address3, isProtected: false)
        }
        if let city = identity.city, !city.isEmpty {
            entry.setField(name: "City", value: city, isProtected: false)
        }
        if let state = identity.state, !state.isEmpty {
            entry.setField(name: "State", value: state, isProtected: false)
        }
        if let postalCode = identity.postalCode, !postalCode.isEmpty {
            entry.setField(name: "Postal Code", value: postalCode, isProtected: false)
        }
        if let country = identity.country, !country.isEmpty {
            entry.setField(name: "Country", value: country, isProtected: false)
        }
        if let ssn = identity.ssn, !ssn.isEmpty {
            entry.setField(name: "SSN", value: ssn, isProtected: true)
        }
        if let username = identity.username, !username.isEmpty {
            entry.rawUserName = username
        }
        if let passportNumber = identity.passportNumber, !passportNumber.isEmpty {
            entry.setField(name: "Passport Number", value: passportNumber, isProtected: true)
        }
        if let licenseNumber = identity.licenseNumber, !licenseNumber.isEmpty {
            entry.setField(name: "License Number", value: licenseNumber, isProtected: true)
        }
    }
}
