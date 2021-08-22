//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppDelegate: UIResponder, UIApplicationDelegate {

    let helpURL = URL(string: "https://keepassium.com/faq")!

    var window: UIWindow?
    
    private var mainCoordinator: MainCoordinator!
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initAppGlobals(application)

        let window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13, *) {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("darkMode") {
                window.overrideUserInterfaceStyle = .dark
            }
        }

        let incomingURL: URL? = launchOptions?[.url] as? URL
        let hasIncomingURL = incomingURL != nil
        
        mainCoordinator = MainCoordinator(window: window)
        mainCoordinator.start(hasIncomingURL: hasIncomingURL)
        window.makeKeyAndVisible()
        
        self.window = window
        return true
    }
    
    private func initAppGlobals(_ application: UIApplication) {
        #if PREPAID_VERSION
        BusinessModel.type = .prepaid
        #else
        BusinessModel.type = .freemium
        #endif
        AppGroup.applicationShared = application
        
        SettingsMigrator.processAppLaunch(with: Settings.current)
        SystemIssueDetector.scanForIssues()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        PremiumManager.shared.finishObservingTransactions()
    }
    
    func application(
        _ application: UIApplication,
        open inputURL: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        let isOpenInPlace = (options[.openInPlace] as? Bool) ?? false
        mainCoordinator.processIncomingURL(inputURL, openInPlace: isOpenInPlace)
        return true
    }
}

extension AppDelegate {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case #selector(showAppHelp):
            return true
        case #selector(lockDatabase):
            return DatabaseManager.shared.isDatabaseOpen
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .format)

        let aboutAppMenuTitle = builder.menu(for: .about)?.children.first?.title
            ?? String.localizedStringWithFormat(LString.menuAboutAppTemplate, AppInfo.name)
        let aboutAppMenuAction = UICommand(
            title: aboutAppMenuTitle,
            action: #selector(showAboutScreen))
        let aboutAppMenu = UIMenu(
            title: "",
            identifier: .about,
            options: .displayInline,
            children: [aboutAppMenuAction]
        )
        builder.remove(menu: .about)
        builder.insertChild(aboutAppMenu, atStartOfMenu: .application)

        let preferencesMenuItem = UIKeyCommand(
            title: builder.menu(for: .preferences)?.children.first?.title ?? LString.menuPreferences,
            action: #selector(showSettingsScreen),
            input: ",",
            modifierFlags: [.command])
        let preferencesMenu = UIMenu(
            identifier: .preferences,
            options: .displayInline,
            children: [preferencesMenuItem]
        )
        builder.remove(menu: .preferences)
        builder.insertSibling(preferencesMenu, afterMenu: .about)

        let createDatabaseMenuItem = UIKeyCommand(
            title: LString.actionCreateDatabase,
            action: #selector(createDatabase),
            input: "n",
            modifierFlags: [.command])
        let openDatabaseMenuItem = UIKeyCommand(
            title: LString.actionOpenDatabase,
            action: #selector(openDatabase),
            input: "o",
            modifierFlags: [.command])
        let lockDatabaseMenuItem = UIKeyCommand(
            title: LString.actionLockDatabase,
            action: #selector(lockDatabase),
            input: "l",
            modifierFlags: [.command]
        )
        let databaseMenu = UIMenu(
            options: .displayInline,
            children: [createDatabaseMenuItem, openDatabaseMenuItem, lockDatabaseMenuItem]
        )
        builder.insertChild(databaseMenu, atStartOfMenu: .file)
    }
    
    @objc
    private func showAppHelp() {
        UIApplication.shared.open(helpURL, options: [:], completionHandler: nil)
    }
    
    @objc
    private func showAboutScreen() {
        mainCoordinator.showAboutScreen()
    }
    
    @objc
    private func showSettingsScreen() {
        mainCoordinator.showSettingsScreen()
    }
    
    @objc
    private func createDatabase() {
        mainCoordinator.createDatabase()
    }
    
    @objc
    private func openDatabase() {
        mainCoordinator.openDatabase()
    }
    
    @objc
    private func lockDatabase() {
        mainCoordinator.lockDatabase()
    }
}

extension LString {
    public static let menuAboutAppTemplate = NSLocalizedString(
        "[Menu/About/title]",
        value: "About %@",
        comment: "Menu title. For example: `About KeePassium`. [appName: String]"
    )
    public static let menuPreferences = NSLocalizedString(
        "[Menu/Preferences/title]",
        value: "Preferences…",
        comment: "Menu title: app settings"
    )
}
