//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension EntryFinderCoordinator {
    final class ItemDecorator: EntryFinderItemDecorator {
        weak var coordinator: EntryFinderCoordinator?

        func getLeadingSwipeActions(for entry: Entry) -> [UIContextualAction]? {
            return nil
        }

        func getTrailingSwipeActions(for entry: Entry) -> [UIContextualAction]? {
            return nil
        }

        func getAccessories(for entry: Entry) -> [UICellAccessory]? {
            var result = [UICellAccessory]()
            switch Passkey.checkPresence(in: entry) {
            case .noPasskey:
                break
            case let .passkeyPresent(isUsable):
                result.append(.passkeyPresenceIndicator(isUsable: isUsable))
            }

            if entry.hasValidTOTP {
                result.append(.otpPresenceIndicator())
            }
            switch coordinator?._autoFillMode {
            case .text:
                result.append(.outlineDisclosure())
            case .credentials, .oneTimeCode, .passkeyRegistration, .passkeyAssertion, .none:
                break
            }
            return result
        }

        func getContextMenu(for entry: Entry, at popoverAnchor: PopoverAnchor) -> UIMenu? {
            guard let coordinator else { return nil }
            var menuItems = [UIMenu]()
            let rememberMenu = coordinator._makeRememberContextMenu(target: entry)
            if let rememberMenu {
                menuItems.append(rememberMenu)
            }
            if let copyFieldMenu = makeCopyEntryFieldMenu(for: entry, inline: rememberMenu == nil) {
                menuItems.append(copyFieldMenu)
            }

            if menuItems.count > 0 {
                return UIMenu(children: menuItems)
            } else {
                return nil
            }
        }
    }
}

extension EntryFinderCoordinator.ItemDecorator {
    func makeCopyEntryFieldMenu(for entry: Entry, inline: Bool) -> UIMenu? {
        let fields = entry.fields.filter {
            !$0.value.isEmpty && !EntryField.isExcludedFromCopying($0.name)
        }
        guard !fields.isEmpty else { return nil }

        var fieldCopyActions = fields.map { field in
            let title = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                field.visibleName
            )
            return UIAction(title: title) { [weak coordinator, weak field] _ in
                guard let field else { return }
                coordinator?._copyToClipboard(field.resolvedValue)
            }
        }

        if entry.hasValidTOTP {
            let title = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                LString.fieldTOTP
            )
            let copyOTPAction = UIAction(title: title) { [weak coordinator, weak entry] _ in
                guard let totpValue = entry?.totpGenerator()?.generate() else {
                    assertionFailure()
                    return
                }
                coordinator?._copyToClipboard(totpValue)
            }
            fieldCopyActions.insert(copyOTPAction, at: 0)
        }

        return UIMenu(
            title: LString.actionCopy,
            image: .symbol(.docOnDoc),
            options: inline ? [.displayInline] : [],
            children: fieldCopyActions
        )
    }
}

extension EntryFinderCoordinator {
    internal func _copyToClipboard(_ text: String) {
        Clipboard.general.copyWithTimeout(text)
        _manualCopyTimestamp = .now
    }
}
