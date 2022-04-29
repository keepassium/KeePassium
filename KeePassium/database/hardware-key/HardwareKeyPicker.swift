//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerDelegate: AnyObject {
    func didSelectKey(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker)
}

class HardwareKeyPicker: UITableViewController, Refreshable {
    weak var delegate: HardwareKeyPickerDelegate?
    
    public var selectedKey: YubiKey? {
        didSet { refresh() }
    }
    
    public let dismissablePopoverDelegate = DismissablePopover(leftButton: .cancel, rightButton: nil)
    
    private let nfcKeys: [YubiKey] = [
        YubiKey(interface: .nfc, slot: .slot1),
        YubiKey(interface: .nfc, slot: .slot2)]
    private let mfiKeys: [YubiKey] = [
        YubiKey(interface: .mfi, slot: .slot1),
        YubiKey(interface: .mfi, slot: .slot2)]

    private enum Section: Int {
        static let allValues = [.noHardwareKey, yubiKeyNFC, yubiKeyMFI]
        case noHardwareKey
        case yubiKeyNFC
        case yubiKeyMFI
        var title: String? {
            switch self {
            case .noHardwareKey:
                return nil
            case .yubiKeyNFC:
                return "NFC"
            case .yubiKeyMFI:
                return "Lightning"
            }
        }
    }
    private var isNFCAvailable = false
    private var isMFIAvailable = false
    
    override var canBecomeFirstResponder: Bool { true }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)

        #if MAIN_APP
        isNFCAvailable = ChallengeResponseManager.instance.supportsNFC
        isMFIAvailable = ChallengeResponseManager.instance.supportsMFI
        #elseif AUTOFILL_EXT
        isNFCAvailable = false
        isMFIAvailable = false
        #endif
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        tableView.removeObserver(self, forKeyPath: "contentSize")
        super.viewWillDisappear(animated)
    }
    
    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?)
    {
        var preferredSize = tableView.contentSize
        if #available(iOS 13, *) {
            preferredSize.width = 400
        }
        self.preferredContentSize = preferredSize
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allValues.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            assertionFailure()
            return 0
        }
        switch section {
        case .noHardwareKey:
            return 1
        case .yubiKeyNFC:
            return nfcKeys.count
        case .yubiKeyMFI:
            return mfiKeys.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            assertionFailure()
            return nil
        }
        return section.title
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let _section = Section(rawValue: section) else { assertionFailure(); return nil }

        switch _section {
        case .noHardwareKey:
            if AppGroup.isAppExtension {
                return LString.hardwareKeyNotAvailableInAutoFill
            }
        case .yubiKeyNFC:
            guard #available(iOS 13, *) else {
                return LString.iOSVersionTooOldForHardwareKey
            }
        default:
            break
        }
        return super.tableView(tableView, titleForFooterInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError()
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let key: YubiKey?
        switch section {
        case .noHardwareKey:
            key = nil
            cell.setEnabled(true)
            cell.isUserInteractionEnabled = true
        case .yubiKeyNFC:
            key = nfcKeys[indexPath.row]
            cell.setEnabled(isNFCAvailable)
            cell.isUserInteractionEnabled = isNFCAvailable
        case .yubiKeyMFI:
            key = mfiKeys[indexPath.row]
            cell.setEnabled(isMFIAvailable)
            cell.isUserInteractionEnabled = isMFIAvailable
        }
        cell.textLabel?.text = getKeyDescription(key)
        cell.accessoryType = (key == selectedKey) ? .checkmark : .none
        return cell
    }
    
    private func getKeyDescription(_ key: YubiKey?) -> String {
        guard let key = key else {
            return LString.noHardwareKey
        }
        
        let result = String.localizedStringWithFormat(
            LString.yubikeySlotNTemplate,
            key.slot.number
        )
        return result
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else {
            assertionFailure()
            return
        }
        
        switch section {
        case .noHardwareKey:
            selectedKey = nil
        case .yubiKeyNFC:
            selectedKey = nfcKeys[indexPath.row]
        case .yubiKeyMFI:
            selectedKey = mfiKeys[indexPath.row]
        }
        delegate?.didSelectKey(selectedKey, in: self)
    }
}

extension HardwareKeyPicker: UIPopoverPresentationControllerDelegate {

    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
        ) -> UIViewController?
    {
        if style != .popover {
            let navVC = controller.presentedViewController as? UINavigationController
            let cancelButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(dismissPopover))
            navVC?.topViewController?.navigationItem.leftBarButtonItem = cancelButton
        }
        return nil // "keep existing"
    }
    
    @objc func dismissPopover() {
        dismiss(animated: true, completion: nil)
    }
}
