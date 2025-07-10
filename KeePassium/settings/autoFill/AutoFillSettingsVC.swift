//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class AutoFillSettingsVC: BaseSettingsViewController<AutoFillSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didPressAutoFillSetup(_ state: AutoFillState, in viewController: AutoFillSettingsVC)
        func didPressAutoFillHelp(in viewController: AutoFillSettingsVC)
        func didChangeQuickAutoFillEnabled(_ isOn: Bool, in viewController: AutoFillSettingsVC)
        func didChangeFillPerfectResult(_ isOn: Bool, in viewController: AutoFillSettingsVC)
        func didChangeCopyOTPOnFill(_ isOn: Bool, in viewController: AutoFillSettingsVC)
    }

    enum AutoFillState {
        case unavailable
        case needsActivation
        case activationFailed
        case active
    }

    weak var delegate: (any Delegate)?
    var setupState: AutoFillState = .unavailable
    var isQuickAutoFillEnabled = false
    var isFillPerfectResult = false
    var isCopyOTPOnFill = false

    override init() {
        super.init()
        title = LString.autoFillSettingsTitle
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    enum Section: SettingsSection {
        case setup(state: AutoFillState)
        case quickAutoFill
        case automaticSearch
        case otp

        var header: String? {
            switch self {
            case .setup, .quickAutoFill:
                return nil
            case .automaticSearch:
                return LString.automaticSearchTitle
            case .otp:
                return LString.oneTimePasswordsTitle
            }
        }

        var footer: String? {
            switch self {
            case .setup(let state):
                switch state {
                case .unavailable:
                    return "⚠️ " + LString.autoFillUnavailableInIntuneDescription
                case .needsActivation, .activationFailed:
                    return LString.autoFillActivationDescription
                case .active:
                    return nil
                }
            case .quickAutoFill:
                return LString.quickAutoFillDescription
            case .automaticSearch:
                return LString.autoFillPerfectMatchDescription
            case .otp:
                return LString.autoFillCopyOTPtoClipboardDescription
            }
        }
    }

    override func refresh() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()

        let isAutoFillActive = setupState == .active

        snapshot.appendSections([.setup(state: setupState)])
        let setupButtonTitle: String
        switch setupState {
        case .unavailable,
             .needsActivation:
            setupButtonTitle = LString.activateAutoFillAction
        case .activationFailed,
             .active:
            setupButtonTitle = LString.autoFillSetupGuideTitle
        }
        let helpButton = UICellAccessory.detail(actionHandler: { [unowned self] in
            delegate?.didPressAutoFillHelp(in: self)
        })
        snapshot.appendItems([
            .basic(.init(
                title: setupButtonTitle,
                image: .symbol(isAutoFillActive ? .infoCircle : .gear),
                isEnabled: setupState != .unavailable,
                decorators: [.action],
                fixedAccessories: isAutoFillActive ? [] : [helpButton],
                handler: { [unowned self] in
                    delegate?.didPressAutoFillSetup(setupState, in: self)
                }
            ))
        ])

        snapshot.appendSections([.quickAutoFill])
        let isQuickAutoFillPurchased = PremiumManager.shared.isAvailable(feature: .canUseQuickTypeAutoFill)
        snapshot.appendItems([
            .toggle(.init(
                title: LString.quickAutoFillTitle,
                isEnabled: isAutoFillActive,
                isOn: isQuickAutoFillEnabled,
                needsPremium: !isQuickAutoFillPurchased,
                handler: { [unowned self] itemConfig in
                    self.isQuickAutoFillEnabled = itemConfig.isOn
                    refresh()
                    delegate?.didChangeQuickAutoFillEnabled(isQuickAutoFillEnabled, in: self)
                }
            ))
        ])

        snapshot.appendSections([.automaticSearch])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.autoFillPerfectMatchTitle,
                isEnabled: isAutoFillActive,
                isOn: isFillPerfectResult,
                handler: { [unowned self] itemConfig in
                    self.isFillPerfectResult = itemConfig.isOn
                    refresh()
                    delegate?.didChangeFillPerfectResult(isFillPerfectResult, in: self)
                }
            ))
        ])

        snapshot.appendSections([.otp])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.autoFillCopyOTPtoClipboardTitle,
                isEnabled: isAutoFillActive,
                isOn: isCopyOTPOnFill,
                handler: { [unowned self] itemConfig in
                    self.isCopyOTPOnFill = itemConfig.isOn
                    refresh()
                    delegate?.didChangeCopyOTPOnFill(isCopyOTPOnFill, in: self)
                }
            ))
        ])

        _dataSource.apply(snapshot, animatingDifferences: true)
    }
}
