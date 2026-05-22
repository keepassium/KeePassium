//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

public class EnpassImporter {
    private struct EnpassVault: Decodable {
        let items: [EnpassItem]
        let folders: [EnpassFolder]?
        let custom_icons: [EnpassCustomIcon]?
    }

    private struct EnpassFolder: Decodable {
        let uuid: String
        let title: String
    }

    private struct EnpassAttachment: Decodable {
        let name: String
        let data: String
    }

    private struct EnpassCustomIcon: Decodable {
        let uuid: String
        let data: String
    }

    private struct EnpassItemIcon: Decodable {
        let uuid: String?
    }

    private struct EnpassItem: Decodable {
        let title: String
        let subtitle: String?
        let category_name: String?
        let note: String?
        let fields: [EnpassField]?
        let attachments: [EnpassAttachment]?
        let folders: [String]?
        let trashed: Int
        let createdAt: Double?
        let updated_at: Double?
        let icon: EnpassItemIcon?
    }

    private struct EnpassField: Decodable {
        let label: String
        let value: String?
        let type: FieldType
        let sensitive: Int
        let deleted: Int
    }

    private enum FieldType: String, Decodable {
        case password
        case username
        case email
        case url
        case totp
        case phone
        case text
        case section
        case custom = ""

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = FieldType(rawValue: rawValue) ?? .custom
        }
    }

    public enum ImportError: LocalizedError {
        case emptyFile
        case parsingFailed(String)
        case corruptedAttachmentData(itemName: String, attachmentName: String)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return LString.Error.importEmptyIncomingFile
            case let .parsingFailed(details):
                let message = [LString.Error.importJSONParsingFailed, details].joined(separator: "\n\n")
                return message
            case let .corruptedAttachmentData(itemName, attachmentName):
                return String(
                    format: LString.Error.importEnpassCorruptedAttachmentTemplate,
                    attachmentName,
                    itemName)
            }
        }
    }

    public init() {}

    private func makeUniqueCustomFieldName(preferredName: String, in entry: Entry) -> String {
        if entry.getField(preferredName) == nil {
            return preferredName
        }

        var index = 1
        while true {
            let candidate = "\(preferredName) (\(index))"
            if entry.getField(candidate) == nil {
                return candidate
            }
            index += 1
        }
    }

    private func makeExtraFieldName(label: String, standardName: String, in entry: Entry) -> String {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLabel = trimmedLabel.lowercased()
        let normalizedStandardName = standardName.lowercased()
        let equivalentStandardNames: Set<String> = {
            if normalizedStandardName == EntryField.otp.lowercased() {
                return [normalizedStandardName, EntryField.totp.lowercased()]
            } else {
                return [normalizedStandardName]
            }
        }()
        let preferredName = (trimmedLabel.isEmpty || equivalentStandardNames.contains(normalizedLabel))
            ? standardName
            : trimmedLabel
        return makeUniqueCustomFieldName(preferredName: preferredName, in: entry)
    }

    public func importFromJSON(fileURL: URL, group: Group) throws -> ([Entry], [Group]) {
        let jsonData = try Data(contentsOf: fileURL)

        guard !jsonData.isEmpty else {
            Diag.error("Incoming JSON file is empty")
            throw ImportError.emptyFile
        }

        do {
            let decoder = JSONDecoder()
            let vault = try decoder.decode(EnpassVault.self, from: jsonData)

            var customIconsByUUID: [String: ByteArray] = [:]
            if let icons = vault.custom_icons {
                for icon in icons where !icon.uuid.isEmpty {
                    guard let pngData = ByteArray(hexString: icon.data) else {
                        continue
                    }
                    customIconsByUUID[icon.uuid] = pngData
                }
            }

            guard !vault.items.isEmpty else {
                Diag.error("No items found in the Enpass vault")
                throw ImportError.emptyFile
            }

            var folders: [String: String] = [:]
            if let enpassFolders = vault.folders {
                for folder in enpassFolders {
                    folders[folder.uuid] = folder.title
                }
            }

            var groups: [Group] = []
            var entries: [Entry] = []

            for item in vault.items {
                let parentGroup: Group
                if let categoryName = item.category_name, !categoryName.isEmpty {
                    if let subgroup = groups.first(where: { $0.name == categoryName }) {
                        parentGroup = subgroup
                    } else {
                        let subgroup = group.createGroup(detached: true)
                        subgroup.name = categoryName
                        groups.append(subgroup)
                        parentGroup = subgroup
                    }
                } else {
                    parentGroup = group
                }

                let creationDate = item.createdAt.map { Date(timeIntervalSince1970: $0) } ?? Date()
                let entry: Entry = parentGroup.createEntry(creationDate: creationDate, detached: parentGroup.isRoot)

                entry.rawTitle = item.trashed == 1 ? "🗑️ " + item.title : item.title
                entry.rawNotes = item.note ?? ""

                if let fields = item.fields {
                    var hasPassword = false
                    var hasUserName = false
                    var hasURL = false
                    var extraURLIndex = 0
                    for field in fields  {
                        if field.deleted == 1 {
                            continue
                        }

                        guard let value = field.value, !value.isEmpty else { continue }

                        switch field.type {
                        case .password:
                            if !hasPassword {
                                entry.rawPassword = value
                                hasPassword = true
                            } else {
                                let fieldName = makeExtraFieldName(
                                    label: field.label,
                                    standardName: EntryField.password,
                                    in: entry
                                )
                                entry.setField(name: fieldName, value: value, isProtected: true)
                            }
                        case .username:
                            if !hasUserName {
                                entry.rawUserName = value
                                hasUserName = true
                            } else {
                                let fieldName = makeExtraFieldName(
                                    label: field.label,
                                    standardName: EntryField.userName,
                                    in: entry
                                )
                                entry.setField(name: fieldName, value: value, isProtected: field.sensitive == 1)
                            }
                        case .email:
                            let fieldName = makeUniqueCustomFieldName(preferredName: "Email", in: entry)
                            entry.setField(name: fieldName, value: value, isProtected: field.sensitive == 1)
                        case .url:
                            if !hasURL {
                                entry.rawURL = value
                                hasURL = true
                            } else {
                                let fieldName = extraURLIndex == 0
                                    ? EntryField.kp2aURLPrefix
                                    : "\(EntryField.kp2aURLPrefix)_\(extraURLIndex)"
                                entry.setField(name: fieldName, value: value, isProtected: false)
                                extraURLIndex += 1
                            }
                        case .totp:
                            if TOTPGeneratorFactory.isValidURI(value) {
                                let fieldName = makeExtraFieldName(
                                    label: field.label,
                                    standardName: EntryField.otp,
                                    in: entry
                                )
                                entry.setField(name: fieldName, value: value, isProtected: true)
                            }
                        case .phone, .text, .section, .custom:
                            if !field.label.isEmpty {
                                let fieldName = makeUniqueCustomFieldName(preferredName: field.label, in: entry)
                                entry.setField(name: fieldName, value: value, isProtected: field.sensitive == 1)
                            }
                        }
                    }
                }

                if entry.rawUserName.isEmpty,
                   let emailFieldValue = entry.getField("Email")?.value,
                   !emailFieldValue.isEmpty {
                    entry.rawUserName = emailFieldValue
                    entry.fields.removeAll { $0.name == "Email" }
                }

                if let attachments = item.attachments {
                    for attachment in attachments {
                        guard let decodedData = Data(base64Encoded: attachment.data) else {
                            Diag.error("Failed to decode base64 attachment data for filename \(attachment.name) in item \(item.title)")
                            throw ImportError.corruptedAttachmentData(
                                itemName: item.title,
                                attachmentName: attachment.name
                            )
                        }

                        if decodedData.isEmpty {
                            Diag.warning("Attachment data is empty (but validly decoded) for filename \(attachment.name) in item \(item.title)")
                        }

                        let data = ByteArray(data: decodedData)
                        guard let attachment = group.database?.makeAttachment(
                            name: attachment.name,
                            data: data
                        ) else {
                            Diag.warning("Failed to create attachment for filename \(attachment.name) in item \(item.title)")
                            continue
                        }
                        entry.attachments.append(attachment)
                    }
                }

                if let uuids = item.folders, !uuids.isEmpty {
                    let tags = uuids.compactMap { uuid in
                        folders[uuid]
                    }
                    if !tags.isEmpty {
                        entry.tags = tags
                    }
                }

                if let iconUUID = item.icon?.uuid,
                   !iconUUID.isEmpty,
                   let pngData = customIconsByUUID[iconUUID],
                   let database2 = group.database as? Database2,
                   let entry2 = entry as? Entry2 {
                    let customIcon = database2.addCustomIcon(pngData: pngData)
                    database2.setCustomIcon(customIcon, for: entry2)
                }

                if let updatedAt = item.updated_at {
                    let modificationDate = Date(timeIntervalSince1970: updatedAt)
                    entry.touch(.modifiedAt(modificationDate))
                } else {
                    entry.touch(.modified)
                }

                if parentGroup.isRoot {
                    entries.append(entry)
                }
            }
            return (entries, groups)
        } catch let decodingError as DecodingError {
            Diag.error("Failed to decode Enpass JSON: \(decodingError)")
            throw ImportError.parsingFailed(decodingError.localizedDescription)
        } catch {
            Diag.error("Unexpected error during Enpass import: \(error)")
            throw error
        }
    }
}
