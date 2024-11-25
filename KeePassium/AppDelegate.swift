//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    private var mainCoordinator: MainCoordinator!

    #if targetEnvironment(macCatalyst)
    private var macUtils: MacUtils?
    #endif

    override var next: UIResponder? { mainCoordinator }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initAppGlobals(application)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let args = ProcessInfo.processInfo.arguments
        if args.contains("darkMode") {
            window.overrideUserInterfaceStyle = .dark
        }

        let incomingURL: URL? = launchOptions?[.url] as? URL
        let hasIncomingURL = incomingURL != nil

        var proposeAppReset = false
        #if targetEnvironment(macCatalyst)
        loadMacUtilsPlugin()
        if let macUtils, macUtils.isControlKeyPressed() {
            proposeAppReset = true
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillDeactivate),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
        #endif

        if UIDevice.current.userInterfaceIdiom == .pad {
            window.makeKeyAndVisible()
            mainCoordinator = MainCoordinator(window: window)
            mainCoordinator.start(hasIncomingURL: hasIncomingURL, proposeReset: proposeAppReset)
        } else {
            mainCoordinator = MainCoordinator(window: window)
            mainCoordinator.start(hasIncomingURL: hasIncomingURL, proposeReset: proposeAppReset)
            window.makeKeyAndVisible()
        }

        self.window = window

        return true
    }

    private func initAppGlobals(_ application: UIApplication) {
        #if PREPAID_VERSION
        BusinessModel.type = .prepaid
        #else
        BusinessModel.type = .freemium
        #endif

        #if INTUNE
        BusinessModel.isIntuneEdition = true
        OneDriveManager.shared.setAuthProvider(MSALOneDriveAuthProvider())
        #else
        BusinessModel.isIntuneEdition = false
        #endif

        AppGroup.applicationShared = application
        Swizzler.swizzle()

        SettingsMigrator.processAppLaunch(with: Settings.current)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        PremiumManager.shared.finishObservingTransactions()
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let result = mainCoordinator.processIncomingURL(
            url,
            sourceApp: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            openInPlace: options[.openInPlace] as? Bool)
        return result
    }

    #if targetEnvironment(macCatalyst)
    private func loadMacUtilsPlugin() {
        let bundleFileName = "MacUtils.bundle"
        guard let bundleURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent(bundleFileName) else {
            Diag.error("Failed to find MacUtils plugin, macOS-specific functions will be limited")
            return
        }

        guard let bundle = Bundle(url: bundleURL) else {
            Diag.error("Failed to load MacUtils plugin, macOS-specific functions will be limited")
            return
        }

        let className = "MacUtils.MacUtilsImpl"
        guard let pluginClass = bundle.classNamed(className) as? MacUtils.Type else {
            Diag.error("Failed to instantiate MacUtils plugin, macOS-specific functions will be limited")
            return
        }

        macUtils = pluginClass.init()
    }

    @objc
    private func sceneWillDeactivate(_ notification: Notification) {
        macUtils?.disableSecureEventInput()
    }
    #endif
}
