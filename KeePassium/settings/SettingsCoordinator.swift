//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class SettingsCoordinator: BaseCoordinator {
    private let settingsVC: SettingsVC

    override init(router: NavigationRouter) {
        settingsVC = SettingsVC.instantiateFromStoryboard()
        super.init(router: router)
        settingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(settingsVC, dismissButtonStyle: .close, animated: true)
    }

    override func refresh() {
        super.refresh()
        guard let topVC = _router.navigationController.topViewController,
              let topRefreshable = topVC as? Refreshable
        else {
            return
        }
        topRefreshable.refresh()
    }
}

extension SettingsCoordinator {
    private func showAppHistoryPage() {
        let appHistoryCoordinator = AppHistoryCoordinator(router: _router)
        appHistoryCoordinator.start()
        addChildCoordinator(appHistoryCoordinator, onDismiss: nil)
    }

    private func showAppearanceSettingsPage() {
        let appearanceVC = SettingsAppearanceVC.instantiateFromStoryboard()
        appearanceVC.delegate = self
        _router.push(appearanceVC, animated: true, onPop: nil)
    }

    private func showSearchSettingsPage() {
        let searchSettingsCoordinator = SearchSettingsCoordinator(router: _router)
        searchSettingsCoordinator.start()
        addChildCoordinator(searchSettingsCoordinator, onDismiss: nil)
    }

    private func showAutoFillSettingsPage() {
        let autoFillSettingsCoordinator = AutoFillSettingsCoordinator(router: _router)
        autoFillSettingsCoordinator.start()
        addChildCoordinator(autoFillSettingsCoordinator, onDismiss: nil)
    }

    private func showAppProtectionSettingsPage() {
        let appProtectionSettingsCoordinator = AppProtectionSettingsCoordinator(router: _router)
        appProtectionSettingsCoordinator.start()
        addChildCoordinator(appProtectionSettingsCoordinator, onDismiss: nil)
    }

    private func showDataProtectionSettingsPage() {
        let dataProtectionSettingsCoordinator = DataProtectionSettingsCoordinator(router: _router)
        dataProtectionSettingsCoordinator.start()
        addChildCoordinator(dataProtectionSettingsCoordinator, onDismiss: nil)
    }

    private func showNetworkAccessSettingsPage() {
        let networkAccessSettingsCoordinator = NetworkAccessSettingsCoordinator(router: _router)
        networkAccessSettingsCoordinator.start()
        addChildCoordinator(networkAccessSettingsCoordinator, onDismiss: nil)
    }

    private func showBackupSettingsPage() {
        let backupSettingsCoordinator = BackupSettingsCoordinator(router: _router)
        backupSettingsCoordinator.start()
        addChildCoordinator(backupSettingsCoordinator, onDismiss: nil)
    }

    private func showDiagnosticsPage() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: _router)
        diagnosticsViewerCoordinator.start()
        addChildCoordinator(diagnosticsViewerCoordinator, onDismiss: nil)
    }

    private func showDonationsPage() {
        let tipBoxCoordinator = TipBoxCoordinator(router: _router)
        tipBoxCoordinator.start()
        addChildCoordinator(tipBoxCoordinator, onDismiss: nil)
    }

    private func showAboutAppPage() {
        let aboutCoordinator = AboutCoordinator(router: _router)
        aboutCoordinator.start()
        addChildCoordinator(aboutCoordinator, onDismiss: nil)
    }

    private func showAppIconSettingsPage() {
        let appIconSwitcherCoordinator = AppIconSwitcherCoordinator(router: _router)
        appIconSwitcherCoordinator.start()
        addChildCoordinator(appIconSwitcherCoordinator, onDismiss: nil)
    }

    private func showDatabaseIconsSettingsPage() {
        let databaseIconSwitcherCoordinator = DatabaseIconSetSwitcherCoordinator(router: _router)
        databaseIconSwitcherCoordinator.start()
        addChildCoordinator(databaseIconSwitcherCoordinator, onDismiss: nil)
    }

    private func showEntryTextFontPicker(at popoverAnchor: PopoverAnchor) {
        let config = UIFontPickerViewController.Configuration()
        let fontPicker = UIFontPickerViewController(configuration: config)
        fontPicker.delegate = self
        fontPicker.modalPresentationStyle = .popover
        popoverAnchor.apply(to: fontPicker.popoverPresentationController)
        _router.present(fontPicker, animated: true, completion: nil)
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
