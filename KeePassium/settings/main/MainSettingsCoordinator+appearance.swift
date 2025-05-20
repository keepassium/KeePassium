//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension MainSettingsCoordinator {
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

    private func showEntryTextFontPicker(at popoverAnchor: PopoverAnchor) {
        let config = UIFontPickerViewController.Configuration()
        let fontPicker = UIFontPickerViewController(configuration: config)
        fontPicker.delegate = self
        fontPicker.modalPresentationStyle = .popover
        popoverAnchor.apply(to: fontPicker.popoverPresentationController)
        _router.present(fontPicker, animated: true, completion: nil)
    }
}

extension MainSettingsCoordinator: SettingsAppearanceViewControllerDelegate {
    func didPressAppIconSettings(in viewController: SettingsAppearanceVC) {
        showAppIconSettings()
    }

    func didPressDatabaseIconsSettings(in viewController: SettingsAppearanceVC) {
        showDatabaseIconsSettings()
    }

    func didPressEntryTextFontSettings(
        at popoverAnchor: PopoverAnchor,
        in viewController: SettingsAppearanceVC
    ) {
        showEntryTextFontPicker(at: popoverAnchor)
    }
}

extension MainSettingsCoordinator: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        if let selectedFontDescriptor = viewController.selectedFontDescriptor {
            Settings.current.entryTextFontDescriptor = selectedFontDescriptor
        }
        viewController.dismiss(animated: true)
    }
}
