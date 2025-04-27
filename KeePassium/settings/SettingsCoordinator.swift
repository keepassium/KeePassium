//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class SettingsCoordinator: NSObject, Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    private let settingsVC: SettingsVC
    private let settingsNotifications: SettingsNotifications

    init(router: NavigationRouter) {
        self.router = router
        settingsVC = SettingsVC.instantiateFromStoryboard()
        settingsNotifications = SettingsNotifications()
        super.init()

        settingsNotifications.observer = self
        settingsVC.delegate = self
    }

    deinit {
        settingsNotifications.stopObserving()

        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        setupCloseButton(in: settingsVC)
        router.push(settingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        settingsNotifications.startObserving()
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
    }

    private func setupCloseButton(in viewController: UIViewController) {
        guard router.navigationController.topViewController == nil else {
            return
        }

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didPressDismiss))
        viewController.navigationItem.leftBarButtonItem = closeButton
    }

    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        router.dismiss(animated: true)
    }

    @objc
    private func premiumStatusDidChange() {
        refresh()
    }

    func refresh() {
        guard let topVC = router.navigationController.topViewController,
              let topRefreshable = topVC as? Refreshable
        else {
            return
        }
        topRefreshable.refresh()
    }
}

extension SettingsCoordinator {
    private func showAppHistoryPage() {
        let appHistoryCoordinator = AppHistoryCoordinator(router: router)
        appHistoryCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        appHistoryCoordinator.start()
        addChildCoordinator(appHistoryCoordinator)
    }

    private func showAppearanceSettingsPage() {
        let appearanceVC = SettingsAppearanceVC.instantiateFromStoryboard()
        appearanceVC.delegate = self
        router.push(appearanceVC, animated: true, onPop: nil)
    }

    private func showSearchSettingsPage() {
        let searchSettingsVC = SettingsSearchVC.instantiateFromStoryboard()
        router.push(searchSettingsVC, animated: true, onPop: nil)
    }

    private func showAutoFillSettingsPage() {
        let autoFillSettingsCoordinator = AutoFillSettingsCoordinator(router: router)
        autoFillSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        autoFillSettingsCoordinator.start()
        addChildCoordinator(autoFillSettingsCoordinator)
    }

    private func showAppProtectionSettingsPage() {
        let appProtectionSettingsCoordinator = AppProtectionSettingsCoordinator(router: router)
        appProtectionSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        appProtectionSettingsCoordinator.start()
        addChildCoordinator(appProtectionSettingsCoordinator)
    }

    private func showDataProtectionSettingsPage() {
        let dataProtectionSettingsCoordinator = DataProtectionSettingsCoordinator(router: router)
        dataProtectionSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        dataProtectionSettingsCoordinator.start()
        addChildCoordinator(dataProtectionSettingsCoordinator)
    }

    private func showNetworkAccessSettingsPage() {
        let networkAccessSettingsCoordinator = NetworkAccessSettingsCoordinator(router: router)
        networkAccessSettingsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        networkAccessSettingsCoordinator.start()
        addChildCoordinator(networkAccessSettingsCoordinator)
    }

    private func showBackupSettingsPage() {
        let dataBackupSettingsVC = SettingsBackupVC.instantiateFromStoryboard()
        router.push(dataBackupSettingsVC, animated: true, onPop: nil)
    }

    private func showDiagnosticsPage() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        addChildCoordinator(diagnosticsViewerCoordinator)
    }

    private func showDonationsPage() {
        let tipBoxCoordinator = TipBoxCoordinator(router: router)
        tipBoxCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        tipBoxCoordinator.start()
        addChildCoordinator(tipBoxCoordinator)
    }

    private func showAboutAppPage() {
        let aboutCoordinator = AboutCoordinator(router: router)
        aboutCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        aboutCoordinator.start()
        addChildCoordinator(aboutCoordinator)
    }

    private func showAppIconSettingsPage() {
        let appIconSwitcherCoordinator = AppIconSwitcherCoordinator(router: router)
        appIconSwitcherCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        appIconSwitcherCoordinator.start()
        addChildCoordinator(appIconSwitcherCoordinator)
    }

    private func showDatabaseIconsSettingsPage() {
        let databaseIconSwitcherCoordinator = DatabaseIconSetSwitcherCoordinator(router: router)
        databaseIconSwitcherCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseIconSwitcherCoordinator.start()
        addChildCoordinator(databaseIconSwitcherCoordinator)
    }

    private func showEntryTextFontPicker(at popoverAnchor: PopoverAnchor) {
        let config = UIFontPickerViewController.Configuration()
        let fontPicker = UIFontPickerViewController(configuration: config)
        fontPicker.delegate = self
        fontPicker.modalPresentationStyle = .popover
        popoverAnchor.apply(to: fontPicker.popoverPresentationController)
        router.present(fontPicker, animated: true, completion: nil)
    }
}

extension SettingsCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else {
            return
        }
        refresh()
    }
}

extension SettingsCoordinator: SettingsViewControllerDelegate {
    func didPressUpgradeToPremium(in viewController: SettingsVC) {
        showPremiumUpgrade(in: settingsVC)
    }

    func didPressManageSubscription(in viewController: SettingsVC) {
        AppStoreHelper.openSubscriptionManagement()
    }

    func didPressShowAppHistory(in viewController: SettingsVC) {
        showAppHistoryPage()
    }

    func didPressAppearanceSettings(in viewController: SettingsVC) {
        showAppearanceSettingsPage()
    }

    func didPressSearchSettings(in viewController: SettingsVC) {
        showSearchSettingsPage()
    }

    func didPressAutoFillSettings(in viewController: SettingsVC) {
        showAutoFillSettingsPage()
    }

    func didPressAppProtectionSettings(in viewController: SettingsVC) {
        guard ManagedAppConfig.shared.isAppProtectionAllowed else {
            viewController.showManagedFeatureBlockedNotification()
            Diag.error("Blocked by organization's policy")
            return
        }
        showAppProtectionSettingsPage()
    }

    func didPressDataProtectionSettings(in viewController: SettingsVC) {
        showDataProtectionSettingsPage()
    }

    func didPressNetworkAccessSettings(in viewController: SettingsVC) {
        showNetworkAccessSettingsPage()
    }

    func didPressBackupSettings(in viewController: SettingsVC) {
        showBackupSettingsPage()
    }

    func didPressShowDiagnostics(in viewController: SettingsVC) {
        showDiagnosticsPage()
    }

    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC) {
        SupportEmailComposer.show(
            subject: .supportRequest,
            parent: viewController,
            popoverAnchor: popoverAnchor
        )
    }

    func didPressDonations(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC) {
        showDonationsPage()
    }

    func didPressAboutApp(in viewController: SettingsVC) {
        showAboutAppPage()
    }
}

extension SettingsCoordinator: SettingsAppearanceViewControllerDelegate {
    func didPressAppIconSettings(in viewController: SettingsAppearanceVC) {
        showAppIconSettingsPage()
    }

    func didPressDatabaseIconsSettings(in viewController: SettingsAppearanceVC) {
        showDatabaseIconsSettingsPage()
    }

    func didPressEntryTextFontSettings(
        at popoverAnchor: PopoverAnchor,
        in viewController: SettingsAppearanceVC
    ) {
        showEntryTextFontPicker(at: popoverAnchor)
    }
}

extension SettingsCoordinator: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        if let selectedFontDescriptor = viewController.selectedFontDescriptor {
            Settings.current.entryTextFontDescriptor = selectedFontDescriptor
        }
        viewController.dismiss(animated: true)
    }
}
