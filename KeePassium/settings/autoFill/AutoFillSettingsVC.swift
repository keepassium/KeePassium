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
        func didChangeContextSavingMode(
            _ mode: AutoFillContextSavingMode,
            in viewController: AutoFillSettingsVC)
        func didChangeIncludeExpiredEntries(_ isOn: Bool, in viewController: AutoFillSettingsVC)
        func didChangeIncludeEntriesWithAutoFillDisabled(_ isOn: Bool, in viewController: AutoFillSettingsVC)
        func didChangeIncludeGroupsWithAutoFillDisabled(_ isOn: Bool, in viewController: AutoFillSettingsVC)
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
    var contextSavingMode: AutoFillContextSavingMode = .inactive
    var isIncludeExpiredEntries = false
    var isIncludeEntriesWithAutoFillDisabled = false
    var isIncludeGroupsWithAutoFillDisabled = false

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
        case contextSaving
        case automaticSearch
        case searchScope
        case otp

        var header: String? {
            switch self {
            case .setup, .quickAutoFill, .contextSaving:
                return nil
            case .automaticSearch:
                return LString.automaticSearchTitle
            case .otp:
                return LString.oneTimePasswordsTitle
            case .searchScope:
                return LString.autoFillSearchScopeTitle
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
            case .contextSaving:
                return LString.autoFillRememberContextDescription
            case .automaticSearch:
                return LString.autoFillPerfectMatchDescription
            case .otp:
                return LString.autoFillCopyOTPtoClipboardDescription
            case .searchScope:
                return nil
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

        snapshot.appendSections([.contextSaving])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.autoFillRememberContextTitle,
                isEnabled: isAutoFillActive,
                isOn: contextSavingMode != .inactive,
                handler: { [unowned self] itemConfig in
                    self.contextSavingMode = itemConfig.isOn ? .hostnameAndPath : .inactive
                    refresh()
                    delegate?.didChangeContextSavingMode(contextSavingMode, in: self)
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

        snapshot.appendSections([.searchScope])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.autoFillIncludeExpiredEntriesTitle,
                isEnabled: isAutoFillActive,
                isOn: isIncludeExpiredEntries,
                handler: { [unowned self] itemConfig in
                    self.isIncludeExpiredEntries = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIncludeExpiredEntries(isIncludeExpiredEntries, in: self)
                }
            )),
            .toggle(.init(
                title: LString.autoFillIncludeEntriesWithAutoFillDisabledTitle,
                isEnabled: isAutoFillActive,
                isOn: isIncludeEntriesWithAutoFillDisabled,
                handler: { [unowned self] itemConfig in
                    self.isIncludeEntriesWithAutoFillDisabled = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIncludeEntriesWithAutoFillDisabled(
                        isIncludeEntriesWithAutoFillDisabled,
                        in: self
                    )
                }
            )),
            .toggle(.init(
                title: LString.autoFillIncludeGroupsWithAutoFillDisabledTitle,
                isEnabled: isAutoFillActive,
                isOn: isIncludeGroupsWithAutoFillDisabled,
                handler: { [unowned self] itemConfig in
                    self.isIncludeGroupsWithAutoFillDisabled = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIncludeGroupsWithAutoFillDisabled(
                        isIncludeGroupsWithAutoFillDisabled,
                        in: self
                    )
                }
            )),
        ], toSection: .searchScope)

        _dataSource.apply(snapshot, animatingDifferences: true)
    }
}
