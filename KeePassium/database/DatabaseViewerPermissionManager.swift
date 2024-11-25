//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib

enum DatabaseViewerPermissionManager {
    enum PermissionElement {
        case editDatabase
        case createGroup
        case createEntry
        case editItem
        case deleteItem
        case moveItem

        case selectItems
        case reorderItems
        case printDatabase
        case auditPasswords
        case downloadFavicons
        case changeMasterKey
        case changeEncryptionSettings
    }
    typealias Permissions = Set<PermissionElement>

    public static func getPermissions(for item: DatabaseItem, in databaseFile: DatabaseFile) -> Permissions {
        switch item {
        case let group as Group:
            var permissions = gatherPermissions(for: group, in: databaseFile)
            trimPermissions(&permissions, for: group)
            return permissions
        case let entry as Entry:
            var permissions = gatherPermissions(for: entry, in: databaseFile)
            trimPermissions(&permissions, for: entry)
            return permissions
        default:
            assertionFailure()
            return []
        }
    }

    private static func trimPermissions(_ permissions: inout Permissions, for group: Group) {
        guard permissions.contains(.editDatabase) else {
            permissions.removeAll()
            return
        }
        permissions.remove([.createEntry, .createGroup], if: group.isSmartGroup)

        let isGroupEmpty = group.entries.isEmpty && group.groups.isEmpty
        let isGroupSorted = Settings.current.groupSortOrder != .noSorting

        permissions.remove(.selectItems, if: group.isSmartGroup || isGroupEmpty)
        permissions.remove(
            .reorderItems,
            if: group.isSmartGroup || isGroupEmpty || isGroupSorted || !permissions.contains(.editItem))
        trimManagedPermissions(&permissions)
    }

    private static func trimPermissions(_ permissions: inout Permissions, for entry: Entry) {
        guard permissions.contains(.editDatabase) else {
            permissions.removeAll()
            return
        }
        trimManagedPermissions(&permissions)
    }

    private static func trimManagedPermissions(_ permissions: inout Permissions) {
        permissions.remove(.auditPasswords, if: !ManagedAppConfig.shared.isPasswordAuditAllowed)
        permissions.remove(.downloadFavicons, if: !ManagedAppConfig.shared.isFaviconDownloadAllowed)
        permissions.remove(.changeEncryptionSettings, if: !ManagedAppConfig.shared.isDatabaseEncryptionSettingsAllowed)
        permissions.remove(.printDatabase, if: !ManagedAppConfig.shared.isDatabasePrintAllowed)
    }

    private static func gatherPermissions(
        for group: Group,
        in databaseFile: DatabaseFile
    ) -> Permissions {
        let canEditDatabase = !databaseFile.status.contains(.readOnly)
        guard canEditDatabase else {
            return []
        }

        var result = Permissions()
        result.insert(.editDatabase)
        result.insert(.createGroup, if: !group.isDeleted)

        if group is Group1 {
            result.insert(.createEntry, if: !group.isDeleted && !group.isRoot)
        } else {
            result.insert(.createEntry, if: !group.isDeleted)
        }

        let isRecycleBin = (group === group.database?.getBackupGroup(createIfMissing: false))
        if isRecycleBin {
            result.insert(.editItem, if: group is Group2)
        } else {
            result.insert(.editItem, if: !group.isDeleted && !(group is Group1 && group.isRoot))
        }

        result.insert(.deleteItem, if: !group.isRoot)

        result.insert(.moveItem, if: !group.isRoot)
        result.remove(.moveItem, if: (group is Group1) && isRecycleBin)

        result.insert(.selectItems)
        result.insert(.reorderItems)
        result.insert(.printDatabase)
        result.insert(.auditPasswords)
        result.insert(.downloadFavicons)
        result.insert(.changeMasterKey)
        result.insert(.changeEncryptionSettings)
        return result
    }

    private static func gatherPermissions(
        for entry: Entry,
        in databaseFile: DatabaseFile
    ) -> Permissions {
        let canEditDatabase = !databaseFile.status.contains(.readOnly)
        guard canEditDatabase else {
            return []
        }

        var result = Permissions()
        result.insert(.editDatabase)
        result.insert(.editItem, if: !entry.isDeleted)
        result.insert(.deleteItem)
        result.insert(.moveItem)
        return result
    }
}

extension DatabaseViewerPermissionManager.Permissions {
    mutating func insert(_ member: Self.Element, if condition: Bool) {
        if condition {
            insert(member)
        }
    }
    mutating func remove(_ member: Self.Element, if condition: Bool) {
        if condition {
            remove(member)
        }
    }
    mutating func remove(_ members: any Collection<Self.Element>, if condition: Bool) {
        if condition {
            members.forEach {
                self.remove($0)
            }
        }
    }
}
