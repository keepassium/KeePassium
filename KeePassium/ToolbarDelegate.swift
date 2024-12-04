//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

#if targetEnvironment(macCatalyst)
import AppKit
#endif
import Foundation
import KeePassiumLib
import UIKit

final class ToolbarDelegate: NSObject {
    private weak var mainCoordinator: MainCoordinator?

    init(mainCoordinator: MainCoordinator) {
        self.mainCoordinator = mainCoordinator
        super.init()

        #if targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reload),
            name: .reloadToolbar,
            object: nil
        )
        #endif
    }

    deinit {
        #if targetEnvironment(macCatalyst)
        NotificationCenter.default.removeObserver(self, name: .reloadToolbar, object: self)
        #endif
    }
}

#if targetEnvironment(macCatalyst)
extension ToolbarDelegate: NSToolbarDelegate {
    private var allItems: [NSToolbarItem.Identifier] {
        return [
            .openDatabase,
            .lockDatabase,
            .space,
            .newEntry,
            .newGroup,
            .newSmartGroup,
            .space,
            .randomGenerator,
            .settings
        ]
    }

    @objc
    private func reload() {
        guard let titlebar = UIApplication.shared.currentScene?.titlebar else {
            return
        }

        for _ in titlebar.toolbar?.items ?? [] {
            titlebar.toolbar?.removeItem(at: 0)
        }

        for item in allItems.reversed() {
            titlebar.toolbar?.insertItem(withItemIdentifier: item, at: 0)
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return allItems
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return allItems
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard mainCoordinator?.isAppLockVisible == false else {
            return nil
        }

        switch itemIdentifier {
        case .openDatabase:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.actionOpenDatabase,
                symbol: .folder,
                selector: #selector(MainCoordinator.kpmOpenDatabase)
            )
        case .lockDatabase:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.actionLockDatabase,
                symbol: .lock,
                selector: #selector(DatabaseViewerActionsManager.kpmLockDatabase)
            )
        case .newEntry:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.titleNewEntry,
                symbol: .docBadgePlus,
                selector: #selector(DatabaseViewerActionsManager.kpmCreateEntry)
            )
        case .newGroup:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.titleNewGroup,
                symbol: .folderBadgePlus,
                selector: #selector(DatabaseViewerActionsManager.kpmCreateGroup)
            )
        case .newSmartGroup:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.titleNewSmartGroup,
                symbol: .folderGridBadgePlus,
                selector: #selector(DatabaseViewerActionsManager.kpmCreateSmartGroup)
            )
        case .randomGenerator:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.PasswordGenerator.titleRandomGenerator,
                symbol: .dieFace3,
                selector: #selector(MainCoordinator.kpmShowRandomGenerator)
            )
        case .settings:
            return createToolbarItem(
                itemIdentifier: itemIdentifier,
                label: LString.titleSettings,
                symbol: .gear,
                selector: #selector(MainCoordinator.kpmShowSettingsScreen)
            )
        default:
            return nil
        }
    }

    private func createToolbarItem(
        itemIdentifier: NSToolbarItem.Identifier,
        label: String,
        symbol: SymbolName,
        selector: Selector?
    ) -> NSToolbarItem {
        let icon = UIImage.symbol(symbol)?.applyingSymbolConfiguration(.init(weight: .medium))
        let button = UIBarButtonItem(image: icon)
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: button)
        toolbarItem.label = label
        toolbarItem.toolTip = label

        guard let selector,
              let target = mainCoordinator?.target(forAction: selector, withSender: self),
              let targetResponder = target as? UIResponder,
              targetResponder.canPerformAction(selector, withSender: self)
        else {
            toolbarItem.action = nil
            toolbarItem.target = nil
            return toolbarItem
        }
        toolbarItem.action = selector
        toolbarItem.target = targetResponder
        return toolbarItem
    }
}

extension NSToolbarItem.Identifier {
    static let openDatabase = NSToolbarItem.Identifier("com.keepassium.toolbar.openDatabase")
    static let lockDatabase = NSToolbarItem.Identifier("com.keepassium.toolbar.lockDatabase")
    static let newEntry = NSToolbarItem.Identifier("com.keepassium.toolbar.newEntry")
    static let newGroup = NSToolbarItem.Identifier("com.keepassium.toolbar.newGroup")
    static let newSmartGroup = NSToolbarItem.Identifier("com.keepassium.toolbar.newSmartGroup")
    static let randomGenerator = NSToolbarItem.Identifier("com.keepassium.toolbar.randomGenerator")
    static let settings = NSToolbarItem.Identifier("com.keepassium.toolbar.settings")
}
#endif
