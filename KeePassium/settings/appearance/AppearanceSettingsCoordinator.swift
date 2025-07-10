//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class AppearanceSettingsCoordinator: BaseCoordinator {
    private let appearanceSettingsVC: AppearanceSettingsVC

    override init(router: NavigationRouter) {
        appearanceSettingsVC = AppearanceSettingsVC()
        super.init(router: router)
        appearanceSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(appearanceSettingsVC, to: _router, animated: true)
        applySettingsToVC()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredContentSizeDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    @objc
    private func preferredContentSizeDidChange() {
        refresh()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        appearanceSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        let settings = Settings.current
        appearanceSettingsVC.isSupportsAlternateIcons = UIApplication.shared.supportsAlternateIcons
        appearanceSettingsVC.databaseIconSet = settings.databaseIconSet
        appearanceSettingsVC.isOpenLastUsedTab = settings.isRememberEntryViewerPage
        appearanceSettingsVC.textScale = Float(settings.textScale)

        appearanceSettingsVC.entryTextFontDescriptor = settings.entryTextFontDescriptor
        appearanceSettingsVC.isHidePasswords = settings.isHideProtectedFields
    }
}

extension AppearanceSettingsCoordinator {
    private func showAppIconSettings() {
        let coordinator = AppIconSwitcherCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    private func showDatabaseIconsSettings() {
        let coordinator = DatabaseIconSetSwitcherCoordinator(router: _router)
        coordinator.start()
        addChildCoordinator(coordinator, onDismiss: nil)
    }

    private func showEntryTextFontPicker() {
        let config = UIFontPickerViewController.Configuration()
        let fontPicker = UIFontPickerViewController(configuration: config)
        fontPicker.delegate = self
        _router.present(fontPicker, animated: true, completion: nil)
    }

    private func resetTextParameters() {
        let settings = Settings.current
        settings.textScale = CGFloat(1.0)
        settings.entryTextFontDescriptor = nil
    }
}

extension AppearanceSettingsCoordinator: AppearanceSettingsVC.Delegate {
    func didPressChangeAppIcon(in viewController: AppearanceSettingsVC) {
        showAppIconSettings()
    }

    func didPressChangeDatabaseIcons(in viewController: AppearanceSettingsVC) {
        showDatabaseIconsSettings()
    }

    func didToggleOpenLastUsedTab(_ isOn: Bool, in viewController: AppearanceSettingsVC) {
        Settings.current.isRememberEntryViewerPage = isOn
        viewController.showNotificationIfManaged(setting: .rememberEntryViewerPage)
        refresh()
    }

    func didChangeTextScale(_ textScale: Float, in viewController: AppearanceSettingsVC) {
        Settings.current.textScale = CGFloat(textScale)

        if Settings.current.isManaged(key: .textScale) {
            viewController.showManagedSettingNotification()
            refresh()
        }
    }

    func didPressFontPicker(in viewController: AppearanceSettingsVC) {
        showEntryTextFontPicker()
    }

    func didPressRestoreDefaults(in viewController: AppearanceSettingsVC) {
        resetTextParameters()
    }

    func didToggleHidePasswords(_ isOn: Bool, in viewController: AppearanceSettingsVC) {
        Settings.current.isHideProtectedFields = isOn
        viewController.showNotificationIfManaged(setting: .hideProtectedFields)
        refresh()
    }
}

extension AppearanceSettingsCoordinator: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        if let selectedFontDescriptor = viewController.selectedFontDescriptor {
            Settings.current.entryTextFontDescriptor = selectedFontDescriptor
        }
        refresh()
        viewController.dismiss(animated: true)
    }
}
