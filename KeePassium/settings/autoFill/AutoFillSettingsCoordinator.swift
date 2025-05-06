//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AutoFillSettingsCoordinator: BaseCoordinator {
    private let autoFillSettingsVC: SettingsAutoFillVC

    override init(router: NavigationRouter) {
        autoFillSettingsVC = SettingsAutoFillVC.instantiateFromStoryboard()
        super.init(router: router)
        autoFillSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(autoFillSettingsVC, animated: true)
    }

    override func refresh() {
        super.refresh()
        autoFillSettingsVC.refresh()
    }
}

extension AutoFillSettingsCoordinator {
    private func maybeSetQuickAutoFill(_ enabled: Bool, in viewController: SettingsAutoFillVC) {
        if enabled {
            performPremiumActionOrOfferUpgrade(
                for: .canUseQuickTypeAutoFill,
                in: viewController,
                actionHandler: {
                    Settings.current.isQuickTypeEnabled = true
                }
            )
        } else {
            Settings.current.isQuickTypeEnabled = false
            viewController.showQuickAutoFillCleared()
            QuickTypeAutoFillStorage.removeAll()
        }
    }
}

extension AutoFillSettingsCoordinator: SettingsAutoFillViewControllerDelegate {
    func didToggleQuickAutoFill(newValue: Bool, in viewController: SettingsAutoFillVC) {
        maybeSetQuickAutoFill(newValue, in: viewController)
    }

    func didToggleCopyTOTP(newValue: Bool, in viewController: SettingsAutoFillVC) {
        Settings.current.isCopyTOTPOnAutoFill = newValue
    }
}
