//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerCoordinatorDelegate: AnyObject {
    func didSelectKey(_ hardwareKey: HardwareKey?, in coordinator: HardwareKeyPickerCoordinator)
}

final class HardwareKeyPickerCoordinator: BaseCoordinator {
    weak var delegate: HardwareKeyPickerCoordinatorDelegate?

    private var selectedKey: HardwareKey?
    private let hardwareKeyPickerVC: HardwareKeyPicker

    override init(router: NavigationRouter) {
        hardwareKeyPickerVC = HardwareKeyPicker.make()
        super.init(router: router)
        hardwareKeyPickerVC.delegate = self
        hardwareKeyPickerVC.selectedKey = selectedKey
    }

    override func start() {
        super.start()
        _pushInitialViewController(hardwareKeyPickerVC, dismissButtonStyle: .cancel, animated: true)
    }

    override func refresh() {
        super.refresh()
        hardwareKeyPickerVC.refresh()
    }
}

extension HardwareKeyPickerCoordinator {

    public func setSelectedKey(_ hardwareKey: HardwareKey?) {
        self.selectedKey = hardwareKey
        hardwareKeyPickerVC.selectedKey = hardwareKey
    }

    private func maybeSelectKey(_ hardwareKey: HardwareKey?) {
        if PremiumManager.shared.isAvailable(feature: .canUseHardwareKeys) {
            setSelectedKey(hardwareKey)
            delegate?.didSelectKey(hardwareKey, in: self)
            dismiss()
        } else {
            setSelectedKey(nil) // reset visual selection to "No key"
            offerPremiumUpgrade(for: .canUseHardwareKeys, in: hardwareKeyPickerVC)
        }
    }
}

extension HardwareKeyPickerCoordinator: HardwareKeyPickerDelegate {
    func didSelectKey(_ hardwareKey: HardwareKey?, in picker: HardwareKeyPicker) {
        maybeSelectKey(hardwareKey)
    }
}
