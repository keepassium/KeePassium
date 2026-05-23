//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension MainCoordinator {
    private var databaseViewerActionsManager: DatabaseViewerCoordinator.ActionsManager {
        _databaseViewerCoordinator?.actionsManager ?? DatabaseViewerCoordinator.defaultActionsManager
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == UIMenuSystem.main,
              UIDevice.current.userInterfaceIdiom == .mac || UIDevice.current.userInterfaceIdiom == .pad
        else {
            return
        }

        builder.remove(menu: .file)
        builder.remove(menu: .help)
        builder.remove(menu: .format)
        builder.remove(menu: .openRecent)
        builder.remove(menu: .spelling)
        builder.remove(menu: .spellingOptions)
        builder.remove(menu: .spellingPanel)
        builder.remove(menu: .substitutions)
        builder.remove(menu: .substitutionOptions)
        builder.remove(menu: .transformations)
        builder.remove(menu: .speech)
        builder.remove(menu: .toolbar)
        builder.remove(menu: .sidebar)
        builder.replaceChildren(ofMenu: .edit) { _ in return [] }
        if isAppLockVisible {
            builder.remove(menu: .edit)
            builder.remove(menu: .view)
            builder.remove(menu: .window)
            return
        }

        insertDatabaseMenu(to: builder)
        insertAboutAppCommand(to: builder)
        insertPreferencesCommand(to: builder)

        insertToolsMenu(to: builder)
        insertPasswordGeneratorCommand(to: builder)

        _databasePickerCoordinator?.buildMenu(with: builder, isDatabaseShown: _databaseViewerCoordinator != nil)
        databaseViewerActionsManager.buildMenu(with: builder)
    }

    override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if isAppLockVisible {
            return self
        }

        for coo in childCoordinators {
            if let cooResponder = coo as? UIResponder,
               cooResponder.canPerformAction(action, withSender: sender)
            {
                return cooResponder
            }
        }
        if databaseViewerActionsManager.canPerformAction(action, withSender: sender) {
            return databaseViewerActionsManager
        }

        if canPerformAction(action, withSender: sender) {
            return self
        }
        return nil
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if isAppLockVisible {
            return false
        }
        switch action {
        case #selector(kpmShowAboutScreen),
             #selector(kpmShowSettingsScreen),
             #selector(kpmShowRandomGenerator):
            return true
        case #selector(kpmCreateDatabase),
             #selector(kpmOpenDatabase),
             #selector(kpmConnectToServer):
            return true
        default:
            return false
        }
    }

    private func insertDatabaseMenu(to builder: UIMenuBuilder) {
        var children = [UIMenuElement]()
        children.append(UIKeyCommand(
            title: LString.titleNewDatabase,
            action: #selector(kpmCreateDatabase),
            hotkey: .createDatabase))
        children.append(UIKeyCommand(
            title: LString.actionOpenDatabase,
            action: #selector(kpmOpenDatabase),
            hotkey: .openDatabase))
        children.append(UIKeyCommand(
            title: LString.actionConnectToServer,
            action: #selector(kpmConnectToServer),
            hotkey: .connectToServer))
        let dbFileMenu = UIMenu(
            title: LString.titleDatabases,
            identifier: .databaseFile,
            children: children)
        builder.insertSibling(dbFileMenu, afterMenu: .application)
    }

    private func insertAboutAppCommand(to builder: UIMenuBuilder) {
        let title = builder.menu(for: .about)?.children.first?.title
            ?? String.localizedStringWithFormat(LString.aboutKeePassiumTitle, AppInfo.name)
        let actionAbout = UICommand(title: title, action: #selector(MainCoordinator.kpmShowAboutScreen))
        let menuAbout = UIMenu(identifier: .about, options: .displayInline, children: [actionAbout])

        builder.replace(menu: .about, with: menuAbout)
    }

    private func insertPreferencesCommand(to builder: UIMenuBuilder) {
        let preferencesCommand = UIKeyCommand(
            title: builder.menu(for: .preferences)?.children.first?.title ?? LString.menuSettingsMacOS,
            action: #selector(kpmShowSettingsScreen),
            hotkey: .appPreferences)
        let preferencesMenu = UIMenu(
            identifier: .preferences,
            options: .displayInline,
            children: [preferencesCommand]
        )
        builder.replace(menu: .preferences, with: preferencesMenu)
    }

    private func insertPasswordGeneratorCommand(to builder: UIMenuBuilder) {
        let passwordGeneratorAction = UIKeyCommand(
            title: LString.PasswordGenerator.titleRandomGenerator,
            action: #selector(kpmShowRandomGenerator),
            hotkey: .passwordGenerator)
        let passGenMenu = UIMenu(
            identifier: .passwordGenerator,
            options: .displayInline,
            children: [passwordGeneratorAction])
        builder.insertChild(passGenMenu, atStartOfMenu: .tools)
    }

    private func insertToolsMenu(to builder: UIMenuBuilder) {
        let toolsMenu = UIMenu(
            title: LString.titleTools,
            identifier: .tools,
            children: []
        )
        builder.insertSibling(toolsMenu, afterMenu: .view)
    }

    @objc func kpmShowAboutScreen() {
        _showAboutScreen(at: nil, in: _presenterForModals)
    }
    @objc func kpmShowSettingsScreen() {
        _showSettingsScreen(in: _presenterForModals)
    }
    @objc func kpmShowRandomGenerator() {
        _showPasswordGenerator(at: nil, in: _presenterForModals)
    }

    @objc func kpmCreateDatabase() {
        _createDatabase()
    }
    @objc func kpmOpenDatabase() {
        _openDatabase()
    }
    @objc func kpmConnectToServer() {
        _connectToServer()
    }
}
