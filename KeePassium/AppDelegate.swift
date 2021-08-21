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
        case #selector(showHelp(_:)):
            return true
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc
    func showHelp(_ sender: Any) {
        UIApplication.shared.open(helpURL, options: [:], completionHandler: nil)
    }
    
    @objc
    func showAbout(_ sender: Any) {
        mainCoordinator.showAboutScreen()
    }
    
    @objc
    func showSettings(_ sender: Any) {
        mainCoordinator.showSettingsScreen()
    }

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .file)
        builder.remove(menu: .edit)
        builder.remove(menu: .format)

        let aboutNameDef = String(format: NSLocalizedString("About %@", comment: ""), AppInfo.name)
        let aboutName = builder.menu(for: .about)?.children.first?.title ?? aboutNameDef;
        let aboutEntry = UICommand(title: aboutName, action: #selector(showAbout))
        let aboutMenu = UIMenu(title: "", identifier: .about, options: .displayInline, children: [aboutEntry])
        builder.remove(menu: .about)
        builder.insertChild(aboutMenu, atStartOfMenu: .application)

        let prefsNameDef = NSLocalizedString("Preferences…", comment: "")
        let prefsName = builder.menu(for: .preferences)?.children.first?.title ?? prefsNameDef
        let prefsEntry = UIKeyCommand(title: prefsName, action: #selector(showSettings), input: ",", modifierFlags: [.command])
        let prefsMenu = UIMenu(title: "", identifier: .preferences, options: .displayInline, children: [prefsEntry])
        // Need to remove the original entry even if it is not shown.
        builder.remove(menu: .preferences)
        builder.insertSibling(prefsMenu, afterMenu: .about)
    }
}
