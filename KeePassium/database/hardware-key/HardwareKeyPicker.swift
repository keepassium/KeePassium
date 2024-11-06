//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol HardwareKeyPickerDelegate: AnyObject {
    func didSelectKey(_ yubiKey: YubiKey?, in picker: HardwareKeyPicker)
}

private final class HardwareKeyPickerCell: UITableViewCell {
    static let reuseIdentifier = "HardwareKeyPickerCell"
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
    private let usbKeys: [YubiKey] = [
        YubiKey(interface: .usb, slot: .slot1),
        YubiKey(interface: .usb, slot: .slot2)]

    private enum Section {
        private static let macOSValues: [Section] = [.noHardwareKey, .yubiKeyUSB]
        private static let iOSValues: [Section] = [.noHardwareKey, .yubiKeyNFC, .yubiKeyMFI, .yubiKeyUSB]

        case noHardwareKey
        case yubiKeyNFC
        case yubiKeyMFI
        case yubiKeyUSB

        static var allValues: [Section] {
            if ProcessInfo.isRunningOnMac {
                return Section.macOSValues
            } else {
                return Section.iOSValues
            }
        }
    }
    private var isNFCAvailable = false
    private var isMFIAvailable = false
    private var isUSBAvailable = false
    private var isMFIoverUSB = false
    private var requiresPremium = true

    override var canBecomeFirstResponder: Bool { true }


    public static func make() -> HardwareKeyPicker {
        return HardwareKeyPicker()
    }

    private init() {
        super.init(style: .insetGrouped)

        title = LString.titleHardwareKeys
        tableView.estimatedSectionHeaderHeight = 18
        tableView.register(
            HardwareKeyPickerCell.self,
            forCellReuseIdentifier: HardwareKeyPickerCell.reuseIdentifier
        )
        addTableFooterButton()

        tableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        tableView.removeObserver(self, forKeyPath: "contentSize")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        isNFCAvailable = ChallengeResponseManager.instance.supportsNFC
        isMFIAvailable = ChallengeResponseManager.instance.supportsMFI
        isUSBAvailable = ChallengeResponseManager.instance.supportsUSB
        isMFIoverUSB = ChallengeResponseManager.instance.supportsMFIoverUSB
    }

    private func addTableFooterButton() {
        var config = UIButton.Configuration.plain()
        config.buttonSize = .small
        config.title = LString.actionLearnMore
        let learnMoreButton = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            URLOpener(self).open(url: URL.AppHelp.yubikeySetup)
        })

        tableView.tableFooterView = learnMoreButton
        learnMoreButton.setNeedsLayout()
        learnMoreButton.layoutIfNeeded()
        learnMoreButton.frame.size = learnMoreButton.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        tableView.tableFooterView = learnMoreButton
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        var preferredSize = tableView.contentSize
        preferredSize.width = 400
        self.preferredContentSize = preferredSize
    }

    func refresh() {
        requiresPremium = !PremiumManager.shared.isAvailable(feature: .canUseHardwareKeys)
        tableView.reloadData()
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allValues.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.allValues[section] {
        case .noHardwareKey:
            return 1
        case .yubiKeyNFC:
            return nfcKeys.count
        case .yubiKeyMFI:
            return mfiKeys.count
        case .yubiKeyUSB:
            return usbKeys.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section.allValues[section] {
        case .noHardwareKey:
            return nil
        case .yubiKeyNFC:
            return LString.hardwareKeyPortNFC
        case .yubiKeyMFI:
            if isMFIoverUSB {
                return LString.hardwareKeyPortLightningOverUSBC
            } else {
                return LString.hardwareKeyPortLightning
            }
        case .yubiKeyUSB:
            return LString.hardwareKeyPortUSB
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section.allValues[section] {
        case .noHardwareKey:
            return nil
        case .yubiKeyNFC:
            if AppGroup.isAppExtension {
                return LString.theseHardwareKeyNotAvailableInAutoFill
            }
        case .yubiKeyMFI:
            if isMFIoverUSB {
                return LString.hardwareKeyRequiresUSBtoLightningAdapter
            }
        case .yubiKeyUSB:
            if ProcessInfo.isCatalystApp {
                if AppGroup.isAppExtension {
                    return LString.theseHardwareKeyNotAvailableInAutoFill
                } else {
                    return nil
                }
            }
            if ProcessInfo.isiPadAppOnMac {
                return LString.usbUnavailableIPadAppOnMac
            }
            return LString.usbHardwareKeyNotSupported
        }
        return super.tableView(tableView, titleForFooterInSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: HardwareKeyPickerCell.reuseIdentifier,
            for: indexPath)

        let key: YubiKey?
        var showPremiumBadge = requiresPremium
        let isEnabled: Bool
        switch Section.allValues[indexPath.section] {
        case .noHardwareKey:
            key = nil
            isEnabled = true
            showPremiumBadge = false
        case .yubiKeyNFC:
            key = nfcKeys[indexPath.row]
            isEnabled = isNFCAvailable
            showPremiumBadge = showPremiumBadge && isNFCAvailable
        case .yubiKeyMFI:
            key = mfiKeys[indexPath.row]
            isEnabled = isMFIAvailable
            showPremiumBadge = showPremiumBadge && isMFIAvailable
        case .yubiKeyUSB:
            key = usbKeys[indexPath.row]
            isEnabled = isUSBAvailable
            showPremiumBadge = showPremiumBadge && isUSBAvailable
        }
        cell.textLabel?.textColor = .primaryText
        cell.textLabel?.text = key?.localizedDescription ?? LString.noHardwareKey
        cell.imageView?.image = showPremiumBadge ? UIImage.premiumBadge : nil
        cell.accessoryType = (key == selectedKey) ? .checkmark : .none
        cell.setEnabled(isEnabled)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section.allValues[indexPath.section] {
        case .noHardwareKey:
            selectedKey = nil
        case .yubiKeyNFC:
            selectedKey = nfcKeys[indexPath.row]
        case .yubiKeyMFI:
            selectedKey = mfiKeys[indexPath.row]
        case .yubiKeyUSB:
            selectedKey = usbKeys[indexPath.row]
        }
        delegate?.didSelectKey(selectedKey, in: self)
    }
}

extension HardwareKeyPicker: UIPopoverPresentationControllerDelegate {

    func presentationController(
        _ controller: UIPresentationController,
        viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle
    ) -> UIViewController? {
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
