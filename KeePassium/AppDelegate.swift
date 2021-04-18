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

        window = UIWindow(frame: UIScreen.main.bounds)
        if #available(iOS 13, *) {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("darkMode") {
                window?.overrideUserInterfaceStyle = .dark
            }
        }

        let rootSplitVC = RootSplitVC()
        mainCoordinator = MainCoordinator(rootSplitViewController: rootSplitVC)
        mainCoordinator.start()
        
        window?.rootViewController = rootSplitVC
        window?.makeKeyAndVisible()
        
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

    @available(iOS 13, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .file)
        builder.remove(menu: .edit)
        builder.remove(menu: .format)
    }
}
