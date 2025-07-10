//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication.LABiometryType

final class AppProtectionSettingsVC: BaseSettingsViewController<AppProtectionSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didChangeAppProtectionEnabled(_ isEnabled: Bool, in viewController: AppProtectionSettingsVC)
        func didPressChangePasscode(in viewController: AppProtectionSettingsVC)
        func didChangeIsUseBiometric(_ isUseBiometric: Bool, in viewController: AppProtectionSettingsVC)
        func didChangeTimeout(_ timeout: Settings.AppLockTimeout, in viewController: AppProtectionSettingsVC)
        func didChangeIsLockOnAppLaunch(_ isLockOnAppLaunch: Bool, in viewController: AppProtectionSettingsVC)
        func didChangeIsLockOnScreenLock(_ isLockOnScreenLock: Bool, in viewController: AppProtectionSettingsVC)
        func didChangeIsLockOnFailedPasscode(
            _ isLockOnFailedPasscode: Bool,
            in viewController: AppProtectionSettingsVC)
        func didChangePasscodeAttemptsBeforeAppReset(
            _ attempts: Settings.PasscodeAttemptsBeforeAppReset,
            in viewController: AppProtectionSettingsVC)
    }

    weak var delegate: (any Delegate)?
    var isBiometricsSupported = false
    var biometryType: LABiometryType?
    var isAppProtectionEnabled: Bool = false
    var isUseBiometric: Bool = false
    var timeout: Settings.AppLockTimeout = .immediately
    var isLockOnScreenLock = false
    var isLockOnAppLaunch: Bool = false
    var isLockOnFailedPasscode: Bool = false
    var passcodeAttemptsBeforeAppReset: Settings.PasscodeAttemptsBeforeAppReset = .never

    override init() {
        super.init()
        title = LString.titleAppProtectionSettings
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    enum Section: SettingsSection {
        case general
        case biometric
        case timeout
        case lockOnLaunch
        case lockOnScreenLock
        case lockOnWrongPasscode
        case resetOnWrongPasscode

        var header: String? {
            switch self {
            case .lockOnWrongPasscode,
                 .resetOnWrongPasscode:
                return LString.wrongPasscodeTitle
            case .general,
                 .biometric,
                 .timeout,
                 .lockOnLaunch,
                 .lockOnScreenLock:
                return nil
            }
        }

        var footer: String? {
            switch self {
            case .general:
                return LString.appProtectionDescription
            case .biometric:
                return LString.biometricAppProtectionDescription
            case .timeout:
                return LString.appProtectionTimeoutDescription
            case .lockOnLaunch:
                return LString.lockAppOnLaunchDescription
            case .lockOnScreenLock:
                return LString.lockAppOnScreenLockDescription
            case .lockOnWrongPasscode:
                return LString.lockOnWrongPasscodeDescription
            case .resetOnWrongPasscode:
                return LString.passcodeAttemptsUntilAppResetDescription
            }
        }
    }

    override func refresh() {
        assert(_dataSource != nil)
        assert(_collectionView != nil)
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()

        snapshot.appendSections([Section.general])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.titleAppProtection,
                image: nil,
                isOn: isAppProtectionEnabled,
                handler: { [unowned self] itemConfig in
                    isAppProtectionEnabled = itemConfig.isOn
                    refresh()
                    delegate?.didChangeAppProtectionEnabled(isAppProtectionEnabled, in: self)
                }
            )),
            .basic(.init(
                title: LString.actionChangePasscode,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                decorators: [.action],
                handler: { [unowned self] in
                    delegate?.didPressChangePasscode(in: self)
                }
            )),
        ])

        let biometryTypeName = biometryType?.name ?? "Touch ID/Face ID"
        snapshot.appendSections([Section.biometric])
        snapshot.appendItems([
            .toggle(.init(
                title: String.localizedStringWithFormat(
                    LString.titleUseBiometryTypeTemplate,
                    biometryTypeName),
                image: .symbol(biometryType?.symbolName),
                isEnabled: isAppProtectionEnabled && isBiometricsSupported,
                isOn: isUseBiometric,
                handler: { [unowned self] itemConfig in
                    isUseBiometric = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIsUseBiometric(isUseBiometric, in: self)
                }
            ))
        ])

        snapshot.appendSections([Section.timeout])
        snapshot.appendItems([
            .picker(.init(
                title: LString.appProtectionTimeoutTitle,
                image: .symbol(.clock),
                isEnabled: isAppProtectionEnabled,
                value: timeout.shortTitle,
                menu: makeTimeoutMenu()
            )),
        ])

        if ProcessInfo.isRunningOnMac {
            snapshot.appendSections([.lockOnScreenLock])
            snapshot.appendItems([
                .toggle(.init(
                    title: LString.lockAppOnScreenLockTitle,
                    isEnabled: isAppProtectionEnabled,
                    isOn: isLockOnScreenLock,
                    handler: { [unowned self] itemConfig in
                        isLockOnScreenLock = itemConfig.isOn
                        refresh()
                        delegate?.didChangeIsLockOnScreenLock(isLockOnScreenLock, in: self)
                    }
                )),
            ])
        }

        snapshot.appendSections([Section.lockOnLaunch])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.lockAppOnLaunchTitle,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                isOn: isLockOnAppLaunch,
                handler: { [unowned self] itemConfig in
                    isLockOnAppLaunch = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIsLockOnAppLaunch(isLockOnAppLaunch, in: self)
                }
            ))
        ])

        snapshot.appendSections([Section.lockOnWrongPasscode])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.lockOnWrongPasscodeTitle,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                isOn: isLockOnFailedPasscode,
                handler: { [unowned self] itemConfig in
                    isLockOnFailedPasscode = itemConfig.isOn
                    refresh()
                    delegate?.didChangeIsLockOnFailedPasscode(isLockOnFailedPasscode, in: self)
                }
            )),
        ])

        snapshot.appendSections([Section.resetOnWrongPasscode])
        snapshot.appendItems([
            .picker(.init(
                title: LString.passcodeAttemptsUntilAppResetTitle,
                isEnabled: isAppProtectionEnabled,
                value: passcodeAttemptsBeforeAppReset.title,
                menu: makePasscodeAttemptsMenu()
            )),
        ])
        _dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func makeTimeoutMenu() -> UIMenu {
        let children = Settings.AppLockTimeout.allValues.map { timeoutOption in
            UIAction(
                title: timeoutOption.fullTitle,
                subtitle: timeoutOption.description,
                state: timeoutOption == self.timeout ? .on : .off,
                handler: { [unowned self] _ in
                    self.timeout = timeoutOption
                    refresh()
                    delegate?.didChangeTimeout(timeoutOption, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }

    private func makePasscodeAttemptsMenu() -> UIMenu {
        let allOptions = Settings.PasscodeAttemptsBeforeAppReset.allCases
        let children = allOptions.map { option in
            UIAction(
                title: option.title,
                state: option == self.passcodeAttemptsBeforeAppReset ? .on : .off,
                handler: { [unowned self] _ in
                    self.passcodeAttemptsBeforeAppReset = option
                    refresh()
                    delegate?.didChangePasscodeAttemptsBeforeAppReset(option, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }
}
