//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabaseViewerCoordinator {
    final class ItemDecorator: GroupViewerItemDecorator {
        weak var coordinator: DatabaseViewerCoordinator?

        init(coordinator: DatabaseViewerCoordinator? = nil) {
            self.coordinator = coordinator
        }

        func getLeadingSwipeActions(for item: Item, context: Context) -> [UIContextualAction]? {
            switch item {
            case .announcement, .emptyStatePlaceholder:
                return nil
            case .group(let group):
                return getLeadingSwipeActions(for: group, context: context)
            case .entry(let entry):
                return getLeadingSwipeActions(for: entry, context: context)
            }
        }

        func getTrailingSwipeActions(for item: Item, context: Context) -> [UIContextualAction]? {
            switch item {
            case .announcement, .emptyStatePlaceholder:
                return nil
            case .group(let group):
                return getTrailingSwipeActions(for: group, context: context)
            case .entry(let entry):
                return getTrailingSwipeActions(for: entry, context: context)
            }
        }

        func getAccessories(for item: Item, context: Context) -> [UICellAccessory]? {
            switch item {
            case .announcement, .emptyStatePlaceholder:
                return nil
            case .group(let group):
                return getAccessories(for: group, context: context)
            case .entry(let entry):
                return getAccessories(for: entry, context: context)
            }
        }

        func getContextMenu(for item: Item, context: Context) -> UIMenu? {
            switch item {
            case .announcement, .emptyStatePlaceholder:
                return nil
            case let .group(group):
                return getContextMenu(for: group, context: context)
            case let .entry(entry):
                return getContextMenu(for: entry, context: context)
            }
        }

        func getAccessibilityActions(for item: Item, context: Context) -> [UIAccessibilityCustomAction]? {
            switch item {
            case .announcement, .emptyStatePlaceholder:
                return nil
            case .group(let group):
                return getAccessibilityActions(for: group, context: context)
            case .entry(let entry):
                return getAccessibilityActions(for: entry, context: context)
            }
        }
    }
}

extension DatabaseViewerCoordinator.ItemDecorator {
    func getLeadingSwipeActions(for group: Group, context: Context) -> [UIContextualAction]? {
        return nil
    }

    func getTrailingSwipeActions(for group: Group, context: Context) -> [UIContextualAction]? {
        guard let coordinator else { return nil }

        let groupPermissions = DatabaseViewerPermissionManager.getPermissions(
            for: group,
            in: coordinator._databaseFile,
        )

        var actions = [UIContextualAction]()
        if groupPermissions.contains(.deleteItem) {
            let deleteAction = UIContextualAction(style: .destructive, title: LString.actionDelete) {
                [weak coordinator, weak group, popoverAnchor = context.popoverAnchor] _, _, completion in
                guard let coordinator, let group else { return }
                coordinator._topGroupViewer?.endBulkEditing(animated: true)
                coordinator._confirmAndDeleteGroup(group, at: popoverAnchor)
                completion(true)
            }
            deleteAction.image = .symbol(.trash)
            deleteAction.backgroundColor = .destructiveTint
            actions.append(deleteAction)
        }
        if groupPermissions.contains(.editItem) {
            let editAction = UIContextualAction(style: .normal, title: LString.actionEdit) {
                [weak coordinator, weak group] _, _, completion in
                guard let coordinator, let group else { return }
                coordinator._topGroupViewer?.endBulkEditing(animated: true)
                coordinator._showGroupEditor(.modify(group: group))
                completion(true)
            }
            editAction.image = .symbol(.squareAndPencil)
            editAction.backgroundColor = .actionTint
            actions.append(editAction)
        }
        if UIAccessibility.isVoiceOverRunning {
            return actions.reversed()
        } else {
            return actions
        }
    }

    func getContextMenu(for group: Group, context: Context) -> UIMenu? {
        guard let coordinator else { return nil }
        let groupPermissions = DatabaseViewerPermissionManager.getPermissions(
            for: group,
            in: coordinator._databaseFile,
        )

        var actions = [UIAction]()
        if groupPermissions.contains(.editItem) {
            actions.append(UIAction(title: LString.actionEdit, image: .symbol(.squareAndPencil)) {
                [weak coordinator, weak group] _ in
                guard let coordinator, let group else { assertionFailure(); return }
                coordinator._showGroupEditor(.modify(group: group))
            })
        }
        if groupPermissions.contains(.moveItem) {
            actions.append(UIAction(title: LString.actionMove, image: .symbol(.folder)) {
                [weak coordinator, weak group] _ in
                guard let coordinator, let group else { assertionFailure(); return }
                coordinator._showItemRelocator(for: [group], mode: .move)
            })
            actions.append(UIAction(title: LString.actionCopy, image: .symbol(.docOnDoc)) {
                [weak coordinator, weak group] _ in
                guard let coordinator, let group else { assertionFailure(); return }
                coordinator._showItemRelocator(for: [group], mode: .copy)
            })
        }
        if groupPermissions.contains(.deleteItem) {
            let popoverAnchor = context.popoverAnchor
            actions.append(
                UIAction(title: LString.actionDelete, image: .symbol(.trash), attributes: .destructive) {
                    [weak coordinator, weak group, popoverAnchor] _ in
                    guard let coordinator, let group else { assertionFailure(); return }
                    coordinator._confirmAndDeleteGroup(group, at: popoverAnchor)
                }
            )
            if let emptyRecycleBinAction = maybeMakeEmptyRecycleBinAction(group, at: popoverAnchor) {
                actions.append(emptyRecycleBinAction)
            }
        }
        return UIMenu(children: actions)
    }

    private func maybeMakeEmptyRecycleBinAction(_ group: Group, at popoverAnchor: PopoverAnchor) -> UIAction? {
        let isRecycleBin = (group === group.database?.getBackupGroup(createIfMissing: false))
        let containsItems = group.entries.count > 0 || group.groups.count > 0
        guard isRecycleBin && containsItems else {
            return nil
        }
        return UIAction(
            title: LString.actionEmptyRecycleBinGroup,
            image: .symbol(.trash),
            attributes: [.destructive]
        ) {
            [weak coordinator, weak group, popoverAnchor] _ in
            guard let coordinator, let group else { assertionFailure(); return }
            coordinator._confirmAndEmptyRecycleBinGroup(group, at: popoverAnchor)
        }
    }

    func getAccessories(for group: Group, context: Context) -> [UICellAccessory]? {
        var result = [UICellAccessory]()
        if group.isExpired {
            result.append(.expiredItemIndicator())
        }
        if group.isSmartGroup {
            result.append(.smartGroupIndicator(isAccessibilityElement: false))
        }
        result.append(.disclosureIndicator())
        result.append(.multiselect(displayed: .whenEditing))
        if !context.isSearchMode,
           let coordinator,
           coordinator._canReorderItems
        {
            result.append(.reorder(displayed: .whenEditing))
        }
        return result
    }

    func getAccessibilityActions(for group: Group, context: Context) -> [UIAccessibilityCustomAction]? {
        return nil
    }
}

extension DatabaseViewerCoordinator.ItemDecorator {
    func getLeadingSwipeActions(for entry: Entry, context: Context) -> [UIContextualAction]? {
        return nil
    }

    func getTrailingSwipeActions(for entry: Entry, context: Context) -> [UIContextualAction]? {
        guard let coordinator else { return nil }

        let entryPermissions = DatabaseViewerPermissionManager
            .getPermissions(for: entry, in: coordinator._databaseFile)

        var actions = [UIContextualAction]()
        if entryPermissions.contains(.deleteItem) {
            let deleteAction = UIContextualAction(style: .destructive, title: LString.actionDelete) {
                [weak coordinator, weak entry, popoverAnchor = context.popoverAnchor] _, _, completion in
                guard let coordinator, let entry else { return }
                coordinator._topGroupViewer?.endBulkEditing(animated: true)
                coordinator._confirmAndDeleteEntry(entry, at: popoverAnchor)
                completion(true)
            }
            deleteAction.image = .symbol(.trash)
            deleteAction.backgroundColor = .destructiveTint
            actions.append(deleteAction)
        }
        if entryPermissions.contains(.editItem) {
            let editAction = UIContextualAction(style: .normal, title: LString.actionEdit) {
                [weak coordinator, weak entry] _, _, completion in
                guard let coordinator, let entry else { return }
                coordinator._topGroupViewer?.endBulkEditing(animated: true)
                coordinator._showEntryEditor(for: entry)
                completion(true)
            }
            editAction.image = .symbol(.squareAndPencil)
            editAction.backgroundColor = .actionTint
            actions.append(editAction)
        }
        if UIAccessibility.isVoiceOverRunning {
            return actions.reversed()
        } else {
            return actions
        }
    }

    func getContextMenu(for entry: Entry, context: Context) -> UIMenu? {
        guard let coordinator else { return nil }

        let entryPermissions = DatabaseViewerPermissionManager
                .getPermissions(for: entry, in: coordinator._databaseFile)

        var actions = [UIAction]()

        #if targetEnvironment(macCatalyst)
        let isAutoTypePossible = coordinator._autoTypeHelper != nil
        if isAutoTypePossible {
            actions.append(UIAction(title: LString.actionAutoType, image: .symbol(.keyboard)) {
                [weak coordinator, weak entry] _ in
                guard let coordinator, let entry else { assertionFailure(); return }
                coordinator._performAutoType(entry: entry)
            })
        }
        #endif

        if entryPermissions.contains(.editItem) {
            actions.append(UIAction(title: LString.actionEdit, image: .symbol(.squareAndPencil)) {
                [weak coordinator, weak entry] _ in
                guard let coordinator, let entry else { assertionFailure(); return }
                coordinator._showEntryEditor(for: entry)
            })
        }
        if entryPermissions.contains(.moveItem) {
            actions.append(UIAction(title: LString.actionMove, image: .symbol(.folder)) {
                [weak coordinator, weak entry] _ in
                guard let coordinator, let entry else { assertionFailure(); return }
                coordinator._showItemRelocator(for: [entry], mode: .move)
            })
            actions.append(UIAction(title: LString.actionCopy, image: .symbol(.docOnDoc)) {
                [weak coordinator, weak entry] _ in
                guard let coordinator, let entry else { assertionFailure(); return }
                coordinator._showItemRelocator(for: [entry], mode: .copy)
            })
        }
        if entryPermissions.contains(.deleteItem) {
            actions.append(
                UIAction(title: LString.actionDelete, image: .symbol(.trash), attributes: .destructive) {
                    [weak coordinator, weak entry, popoverAnchor = context.popoverAnchor] _ in
                    guard let coordinator, let entry else { assertionFailure(); return }
                    coordinator._confirmAndDeleteEntry(entry, at: popoverAnchor)
                }
            )
        }
        return UIMenu(children: actions)
    }

    func getAccessories(for entry: Entry, context: Context) -> [UICellAccessory]? {
        var result = [UICellAccessory]()
        if entry.isExpired {
            result.append(.expiredItemIndicator())
        }
        if entry.attachments.count > 0 {
            result.append(.attachmentPresenceIndicator())
        }

        switch Passkey.checkPresence(in: entry) {
        case let .passkeyPresent(isUsable):
            result.append(.passkeyPresenceIndicator(isUsable: isUsable))
        case .noPasskey: break
        }

        if let otpGenerator = entry.totpGenerator() {
            result.append(.otpCode(
                generator: otpGenerator,
                mode: context.otpDisplayMode,
                onTap: { [weak self, weak entry, weak presenter = context.contentView] otpValue in
                    guard let self,
                          let groupViewer = coordinator?._topGroupViewer,
                          let entry
                    else { assertionFailure(); return }
                    switch context.otpDisplayMode {
                    case .protected:
                        groupViewer.setOTPDisplayMode(.visible, for: entry)
                        copyOTPToClipboard(otpValue, presenter: presenter ?? groupViewer.view)
                    case .visible:
                        groupViewer.setOTPDisplayMode(.protected, for: entry)
                    case .prominent:
                        copyOTPToClipboard(otpValue, presenter: presenter ?? groupViewer.view)
                    }
                    groupViewer.refreshVisibleCells()
                }
            ))
        }
        result.append(.multiselect(displayed: .whenEditing))
        if !context.isSearchMode,
           let coordinator,
           coordinator._canReorderItems
        {
            result.append(.reorder(displayed: .whenEditing))
        }
        return result
    }

    func getAccessibilityActions(for entry: Entry, context: Context) -> [UIAccessibilityCustomAction]? {
        var actions = [UIAccessibilityCustomAction]()

        let category = ItemCategory.default
        let copyableFields = entry.fields
            .filter { !$0.value.isEmpty && !EntryField.isExcludedFromCopying($0.name) }
            .sorted { category.compare($0.name, $1.name) }
        copyableFields.forEach { field in
            let actionName = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                field.visibleName)
            let action = UIAccessibilityCustomAction(name: actionName) { [weak field] _ -> Bool in
                if let fieldValue = field?.resolvedValue {
                    Clipboard.general.copyWithTimeout(fieldValue)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: LString.titleCopiedToClipboard
                    )
                }
                return true
            }
            actions.append(action)
        }

        if entry.hasValidTOTP {
            let actionName = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                LString.fieldTOTP
            )
            let copyOTPAction = UIAccessibilityCustomAction(name: actionName) { [weak entry] _ -> Bool in
                guard let totpValue = entry?.totpGenerator()?.generate() else {
                    assertionFailure()
                    return false
                }
                Clipboard.general.copyWithTimeout(totpValue)
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LString.titleCopiedToClipboard
                )
                return true
            }
            actions.append(copyOTPAction)
        }

        return actions
    }
}

extension DatabaseViewerCoordinator.ItemDecorator {
    private func copyOTPToClipboard(_ otpValue: String, presenter: UIView?) {
        Clipboard.general.copyWithTimeout(otpValue)
        HapticFeedback.play(.copiedToClipboard)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: NSAttributedString(
                    string: LString.titleCopiedToClipboard,
                    attributes: [.accessibilitySpeechQueueAnnouncement: true]
                )
            )
        } else {
            presenter?.hideAllToasts(includeActivity: true, clearQueue: true)
            presenter?.makeToast(
                LString.titleCopiedToClipboard,
                duration: 1.0,
                position: .center,
                image: .symbol(.docOnDoc)
            )
        }
    }
}
