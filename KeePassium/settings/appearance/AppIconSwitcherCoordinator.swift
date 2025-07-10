//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppIconSwitcherCoordinator: BaseCoordinator {
    private let picker: AppIconPicker

    override init(router: NavigationRouter) {
        picker = AppIconPicker.instantiateFromStoryboard()
        super.init(router: router)
        picker.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(picker, animated: true)
    }

    override func refresh() {
        super.refresh()
        picker.refresh()
    }
}

extension AppIconSwitcherCoordinator: AppIconPickerDelegate {
    func didSelectIcon(_ appIcon: AppIcon, in appIconPicker: AppIconPicker) {
        assert(UIApplication.shared.supportsAlternateIcons)
        setAppIcon(appIcon)
    }

    private func setAppIcon(_ appIcon: AppIcon) {
        UIApplication.shared.setAlternateIconName(appIcon.key) { [weak self] error in
            if let error {
                Diag.error("Failed to switch app icon [message: \(error.localizedDescription)")
            } else {
                Diag.info("App icon switched to \(appIcon.key ?? "default")")
            }
            self?.picker.refresh()
        }
    }
}
