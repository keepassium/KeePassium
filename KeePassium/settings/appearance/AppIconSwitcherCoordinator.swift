//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppIconSwitcherCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    private let router: NavigationRouter
    private let picker: AppIconPicker
    private let premiumUpgradeHelper = PremiumUpgradeHelper()
    
    init(router: NavigationRouter) {
        self.router = router
        picker = AppIconPicker.instantiateFromStoryboard()
        picker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(picker, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPremiumStatus),
            name: PremiumManager.statusUpdateNotification,
            object: nil)
    }
    
    @objc private func refreshPremiumStatus() {
        picker.refresh()
    }
}

extension AppIconSwitcherCoordinator: AppIconPickerDelegate {
    func didSelectIcon(_ appIcon: AppIcon, in appIconPicker: AppIconPicker) {
        assert(UIApplication.shared.supportsAlternateIcons)
        if AppIcon.isPremium(appIcon) {
            premiumUpgradeHelper.performActionOrOfferUpgrade(.canChangeAppIcon, in: picker) {
                [weak self] in
                self?.setAppIcon(appIcon)
            }
        } else {
            setAppIcon(appIcon)
        }
    }
    
    private func setAppIcon(_ appIcon: AppIcon) {
        UIApplication.shared.setAlternateIconName(appIcon.key) { [weak self] error in
            if let error = error {
                Diag.error("Failed to switch app icon [message: \(error.localizedDescription)")
            } else {
                Diag.info("App icon switched to \(appIcon.key ?? "default")")
            }
            self?.picker.refresh()
        }
    }
}
