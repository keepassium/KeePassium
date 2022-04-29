//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerCoordinatorDelegate: AnyObject {
    func didSelectKey(_ yubiKey: YubiKey?, in coordinator: HardwareKeyPickerCoordinator)
}

final class HardwareKeyPickerCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: HardwareKeyPickerCoordinatorDelegate?
    
    private var selectedKey: YubiKey?
    
    private let router: NavigationRouter
    private let hardwareKeyPickerVC: HardwareKeyPicker
    
    init(router: NavigationRouter) {
        self.router = router
        hardwareKeyPickerVC = HardwareKeyPicker.instantiateFromStoryboard()
        hardwareKeyPickerVC.delegate = self
        hardwareKeyPickerVC.selectedKey = selectedKey
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupCancelButton(in: hardwareKeyPickerVC)
        router.push(hardwareKeyPickerVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        #if MAIN_APP
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
        #endif
    }
    
    private func setupCancelButton(in viewController: UIViewController) {
        guard router.navigationController.topViewController == nil else {
            return
        }
        
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(didPressDismiss))
        viewController.navigationItem.leftBarButtonItem = cancelButton
    }
    
    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    @objc
    private func premiumStatusDidChange() {
        refresh()
    }
    
    func refresh() {
        hardwareKeyPickerVC.refresh()
    }
    
    private func dismiss(animated: Bool) {
        router.pop(viewController: hardwareKeyPickerVC, animated: animated) 
    }
}

extension HardwareKeyPickerCoordinator {
    
    public func setSelectedKey(_ yubiKey: YubiKey?) {
        self.selectedKey = yubiKey
        hardwareKeyPickerVC.selectedKey = yubiKey
    }
    
    #if MAIN_APP
    private func maybeSelectKey(_ yubiKey: YubiKey?) {
        if PremiumManager.shared.isAvailable(feature: .canUseHardwareKeys) {
            setSelectedKey(yubiKey)
            delegate?.didSelectKey(yubiKey, in: self)
            dismiss(animated: true)
        } else {
            setSelectedKey(nil) // reset visual selection to "No key"
            offerPremiumUpgrade(for: .canUseHardwareKeys, in: hardwareKeyPickerVC)
        }
    }
    #endif
}

extension HardwareKeyPickerCoordinator: HardwareKeyPickerDelegate {
    func didSelectKey(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        #if MAIN_APP
        didSelectKeyInMainApp(yubiKey, in: picker)
        #elseif AUTOFILL_EXT
        didSelectKeyInAutoFill(yubiKey, in: picker)
        #else
        assertionFailure("You should not be here")
        #endif
    }

    #if MAIN_APP
    private func didSelectKeyInMainApp(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        maybeSelectKey(yubiKey)
    }
    #endif
        
    #if AUTOFILL_EXT
    private func didSelectKeyInAutoFill(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        guard yubiKey == nil else {
            Diag.warning("Hardware keys are not available in AutoFill")
            assertionFailure("How did we end up here?")
            return
        }
        setSelectedKey(nil)
        delegate?.didSelectKey(nil, in: self)
        dismiss(animated: true)
    }
    #endif
}
