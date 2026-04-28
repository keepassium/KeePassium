//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib

final class RecentAutoFillEntryTracker {

    private struct RecentEntryData: Codable {
        let uuid: UUID
        let timestamp: Date
        let databaseDescriptor: String
    }

    static let shared = RecentAutoFillEntryTracker()

    private let maxAge: TimeInterval = 10

    private init() {}

    func recordRecentEntry(_ entry: Entry, from databaseFile: DatabaseFile) {
        guard let databaseDescriptor = databaseFile.descriptor else {
            Diag.warning("Cannot record recent entry: database descriptor missing")
            return
        }

        let data = RecentEntryData(
            uuid: entry.uuid,
            timestamp: Date.now,
            databaseDescriptor: databaseDescriptor
        )

        do {
            let encodedData = try JSONEncoder().encode(data)
            try Keychain.shared.setRecentAutoFillEntry(encodedData)
            Diag.debug("Recorded recent AutoFill entry: \(entry.uuid.uuidString)")
        } catch {
            Diag.warning("Failed to record recent AutoFill entry: \(error)")
        }
    }

    func getRecentEntry(from databaseFile: DatabaseFile) -> Entry? {
        guard let databaseDescriptor = databaseFile.descriptor else {
            Diag.debug("Cannot get recent entry: database descriptor missing")
            return nil
        }

        do {
            guard let encodedData = try Keychain.shared.getRecentAutoFillEntry() else {
                return nil
            }

            let data = try JSONDecoder().decode(RecentEntryData.self, from: encodedData)

            guard data.databaseDescriptor == databaseDescriptor else {
                Diag.debug("Recent AutoFill entry is from different database")
                return nil
            }

            let age = Date.now.timeIntervalSince(data.timestamp)
            guard age <= maxAge else {
                Diag.debug("Recent AutoFill entry expired (age: \(age)s)")
                clearRecentEntry()
                return nil
            }

            let options = Settings.current.autoFillInclusionOptions
            guard let entry = databaseFile.database.root?.findEntry(byUUID: data.uuid)
            else {
                Diag.debug("Recent AutoFill entry not found or invalid")
                clearRecentEntry()
                return nil
            }

            let parentGroup2 = entry.parent as? Group2
            let includeFromGroup = parentGroup2?.shouldIncludeInAutoFill(with: options) ?? true
            guard includeFromGroup, entry.isAutoFillable(with: options) else {
                Diag.debug("Recent AutoFill entry not found or invalid")
                clearRecentEntry()
                return nil
            }

            Diag.debug("Found valid recent AutoFill entry: \(entry.resolvedTitle)")
            return entry
        } catch {
            Diag.warning("Failed to retrieve recent AutoFill entry: \(error)")
            clearRecentEntry()
            return nil
        }
    }

    func clearRecentEntry() {
        do {
            try Keychain.shared.removeRecentAutoFillEntry()
            Diag.debug("Cleared recent AutoFill entry")
        } catch {
            Diag.warning("Failed to clear recent AutoFill entry: \(error)")
        }
    }
}
