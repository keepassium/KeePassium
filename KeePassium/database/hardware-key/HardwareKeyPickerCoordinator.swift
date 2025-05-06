//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerCoordinatorDelegate: AnyObject {
    func didSelectKey(_ yubiKey: YubiKey?, in coordinator: HardwareKeyPickerCoordinator)
}

final class HardwareKeyPickerCoordinator: BaseCoordinator {
    weak var delegate: HardwareKeyPickerCoordinatorDelegate?

    private var selectedKey: YubiKey?
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

    public func setSelectedKey(_ yubiKey: YubiKey?) {
        self.selectedKey = yubiKey
        hardwareKeyPickerVC.selectedKey = yubiKey
    }

    private func maybeSelectKey(_ yubiKey: YubiKey?) {
        if PremiumManager.shared.isAvailable(feature: .canUseHardwareKeys) {
            setSelectedKey(yubiKey)
            delegate?.didSelectKey(yubiKey, in: self)
            dismiss()
        } else {
            setSelectedKey(nil) // reset visual selection to "No key"
            offerPremiumUpgrade(for: .canUseHardwareKeys, in: hardwareKeyPickerVC)
        }
    }
}

extension HardwareKeyPickerCoordinator: HardwareKeyPickerDelegate {
    func didSelectKey(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        maybeSelectKey(yubiKey)
    }
}
