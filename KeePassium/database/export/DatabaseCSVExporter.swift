//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib

public final class DatabaseCSVExporter {
    public init() {}

    public func export(root: Group) -> String {
        let header = [
            "Group", "Title", "Username", "Password", "URL",
            "Notes", "TOTP", "Icon", "Last Modified", "Created"
        ]

        var csvLines = [header]
        processGroup(root, parentGroupName: nil, csvLines: &csvLines)

        let csvString = csvLines
            .map { values in
                values.map(quoteValue).joined(separator: ",")
            }.joined(separator: "\n")
        return csvString
    }

    private func processGroup(_ group: Group, parentGroupName: String?, csvLines: inout [[String]]) {
        let groupName: String
        if let parentGroupName {
            groupName = parentGroupName + "/" + group.name
        } else {
            groupName = group.name
        }

        for entry in group.entries {
            csvLines.append(createRow(for: entry, groupName: groupName))
        }

        for subgroup in group.groups {
            processGroup(subgroup, parentGroupName: groupName, csvLines: &csvLines)
        }
    }

    private func createRow(for entry: Entry, groupName: String) -> [String] {
        return [
            groupName,
            entry.resolvedTitle,
            entry.resolvedUserName,
            entry.resolvedPassword,
            entry.resolvedURL,
            entry.resolvedNotes,
            entry.getField(EntryField.otp)?.resolvedValue ?? "",
            String(entry.iconID.rawValue),
            entry.lastModificationTime.iso8601String(),
            entry.creationTime.iso8601String()
        ]
    }

    private func quoteValue(_ value: String) -> String {
        let escapedValue = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapedValue)\""
    }
}
