//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class DataProtectionSettingsVC: BaseSettingsViewController<DataProtectionSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didChangeRememberMasterKeys(_ isRemember: Bool, in viewController: DataProtectionSettingsVC)
        func didPressClearMasterKeys(in viewController: DataProtectionSettingsVC)
        func didChangeDatabaseTimeout(
            _ timeout: Settings.DatabaseLockTimeout,
            in viewController: DataProtectionSettingsVC)
        func didChangeLockOnReboot(_ isLockOnRestart: Bool, in viewController: DataProtectionSettingsVC)
        func didChangeLockOnTimeout(_ isLockOnTimeout: Bool, in viewController: DataProtectionSettingsVC)
        func didChangeLockOnScreenLock(
            _ isLockDatabaseOnScreenLock: Bool,
            in viewController: DataProtectionSettingsVC
        )
        func didChangeShakeAction(
            _ action: Settings.ShakeGestureAction,
            in viewController: DataProtectionSettingsVC)
        func didChangeConfirmShakeAction(_ isConfirm: Bool, in viewController: DataProtectionSettingsVC)
        func didChangeClipboardTimeout(
            _ timeout: Settings.ClipboardTimeout,
            in viewController: DataProtectionSettingsVC)
        func didChangeUseUniversalClipboard(_ isUse: Bool, in viewController: DataProtectionSettingsVC)
        func didChangeHideProtectedFields(_ isHide: Bool, in viewController: DataProtectionSettingsVC)
        func didChangeRememberKeyFiles(_ isRemember: Bool, in viewController: DataProtectionSettingsVC)
        func didPressClearKeyFileAssociations(in viewController: DataProtectionSettingsVC)
        func didChangeRememberFinalKeys(_ isRemember: Bool, in viewController: DataProtectionSettingsVC)
    }

    weak var delegate: (any Delegate)?
    var isRememberMasterKeys = false
    var databaseTimeout: Settings.DatabaseLockTimeout = .immediately
    var isLockOnReboot = false
    var isLockOnTimeout = false
    var isLockOnScreenLock = false
    var shakeAction: Settings.ShakeGestureAction = .nothing
    var isConfirmShakeAction = false
    var clipboardTimeout: Settings.ClipboardTimeout = .immediately
    var isUseUniversalClipboard = false
    var isHideProtectedFields = false
    var isRememberKeyFiles = false
    var isRememberFinalKeys = false

    override init() {
        super.init()
        title = LString.dataProtectionSettingsTitle
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    enum Section: SettingsSection {
        case masterKeys
        case timeout
        case lockConditions
        case clipboard
        case universalClipboard
        case shake
        case protectedFields
        case keyFiles
        case advanced

        var header: String? {
            switch self {
            case .masterKeys:
                return LString.quickUnlockTitle
            case .timeout:
                return LString.dataProtectionAutomaticLockTitle
            case .lockConditions:
                return nil
            case .clipboard:
                return LString.clipboardTitle
            case .universalClipboard:
                return nil
            case .shake:
                return nil
            case .protectedFields:
                return LString.protectedFieldsTitle
            case .keyFiles:
                return LString.keyFilesTitle
            case .advanced:
                return LString.dataProtectionAdvancedTitle
            }
        }

        var footer: String? {
            switch self {
            case .masterKeys:
                return LString.rememberMasterKeysDescription
            case .timeout:
                return LString.databaseTimeoutDescription
            case .lockConditions:
                return nil
            case .clipboard:
                return LString.clipboardTimeoutDescription
            case .universalClipboard:
                return LString.universalClipboardDescription
            case .shake:
                guard ManagedAppConfig.shared.isAppProtectionAllowed else {
                    return nil
                }
                return LString.shakeGestureConfirmationDescription
            case .protectedFields:
                return LString.hidePasswordsDescription
            case .keyFiles:
                return LString.rememberKeyFilesDescription
            case .advanced:
                return LString.cacheDerivedKeysDescription
            }
        }
    }

    override func refresh() {
        assert(_dataSource != nil)
        assert(_collectionView != nil)
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()

        snapshot.appendSections([.masterKeys])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.rememberMasterKeysTitle,
                image: nil,
                isOn: isRememberMasterKeys,
                handler: { [unowned self] itemConfig in
                    isRememberMasterKeys = itemConfig.isOn
                    refresh()
                    delegate?.didChangeRememberMasterKeys(isRememberMasterKeys, in: self)
                }
            )),
            .basic(.init(
                title: LString.clearMasterKeysAction,
                image: nil,
                isEnabled: isRememberMasterKeys,
                decorators: [.destructive],
                handler: { [unowned self] in
                    delegate?.didPressClearMasterKeys(in: self)
                }
            )),
        ])

        snapshot.appendSections([.timeout])
        snapshot.appendItems([
            .picker(.init(
                title: LString.databaseTimeoutTitle,
                image: nil,
                value: databaseTimeout.shortTitle,
                menu: makeDatabaseTimeoutMenu()
            )),
            .toggle(.init(
                title: LString.clearMasterKeysOnTimeoutTitle,
                image: nil,
                isOn: isLockOnTimeout,
                handler: { [unowned self] itemConfig in
                    isLockOnTimeout = itemConfig.isOn
                    refresh()
                    delegate?.didChangeLockOnTimeout(isLockOnTimeout, in: self)
                }
            )),
        ])

        snapshot.appendSections([.lockConditions])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.lockDatabasesOnRebootTitle,
                image: nil,
                isOn: isLockOnReboot,
                handler: { [unowned self] itemConfig in
                    isLockOnReboot = itemConfig.isOn
                    refresh()
                    delegate?.didChangeLockOnReboot(isLockOnReboot, in: self)
                }
            )),
        ])
        if ProcessInfo.isRunningOnMac {
            snapshot.appendItems([
                .toggle(.init(
                    title: LString.lockDatabasesOnScreenLockTitle,
                    image: nil,
                    isOn: isLockOnScreenLock,
                    handler: { [unowned self] itemConfig in
                        isLockOnScreenLock = itemConfig.isOn
                        refresh()
                        delegate?.didChangeLockOnScreenLock(isLockOnScreenLock, in: self)
                    }
                )),
            ])
        }

        if !ProcessInfo.isRunningOnMac {
            let canConfirmShakeAction = shakeAction != .nothing
            snapshot.appendSections([.shake])
            snapshot.appendItems([
                .picker(.init(
                    title: LString.shakeGestureActionTitle,
                    value: shakeAction.shortTitle,
                    menu: makeShakeActionMenu()
                )),
                .toggle(.init(
                    title: LString.shakeGestureConfirmationTitle,
                    isEnabled: canConfirmShakeAction,
                    isOn: canConfirmShakeAction && isConfirmShakeAction,
                    handler: { [unowned self] itemConfig in
                        isConfirmShakeAction.toggle()
                        refresh()
                        delegate?.didChangeConfirmShakeAction(isConfirmShakeAction, in: self)
                    }
                ))
            ])
        }

        snapshot.appendSections([.clipboard])
        snapshot.appendItems([
            .picker(.init(
                title: LString.clipboardTimeoutTitle,
                value: clipboardTimeout.shortTitle,
                menu: makeClipboardTimeoutMenu()
            )),
        ])

        snapshot.appendSections([.universalClipboard])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.universalClipboardTitle,
                isOn: isUseUniversalClipboard,
                handler: { [unowned self] itemConfig in
                    self.isUseUniversalClipboard = itemConfig.isOn
                    refresh()
                    delegate?.didChangeUseUniversalClipboard(isUseUniversalClipboard, in: self)
                }
            )),
        ])

        snapshot.appendSections([.protectedFields])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.hidePasswordsTitle,
                isOn: isHideProtectedFields,
                handler: { [unowned self] itemConfig in
                    self.isHideProtectedFields = itemConfig.isOn
                    refresh()
                    delegate?.didChangeHideProtectedFields(isHideProtectedFields, in: self)
                }
            )),
        ])

        snapshot.appendSections([.keyFiles])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.rememberKeyFilesTitle,
                isOn: isRememberKeyFiles,
                handler: { [unowned self] itemConfig in
                    self.isRememberKeyFiles = itemConfig.isOn
                    refresh()
                    delegate?.didChangeRememberKeyFiles(isRememberKeyFiles, in: self)
                }
            )),
            .basic(.init(
                title: LString.clearKeyFileAssociationsAction,
                isEnabled: isRememberKeyFiles,
                decorators: [.destructive],
                handler: { [unowned self] in
                    delegate?.didPressClearKeyFileAssociations(in: self)
                }
            ))
        ])

        snapshot.appendSections([.advanced])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.cacheDerivedKeysTitle,
                isOn: isRememberFinalKeys,
                handler: { [unowned self] itemConfig in
                    self.isRememberFinalKeys = itemConfig.isOn
                    refresh()
                    delegate?.didChangeRememberFinalKeys(isRememberFinalKeys, in: self)
                }
            ))
        ])
        _dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func makeDatabaseTimeoutMenu() -> UIMenu {
        let children = Settings.DatabaseLockTimeout.allValues.map { timeoutOption in
            UIAction(
                title: timeoutOption.title,
                subtitle: timeoutOption.description,
                state: timeoutOption == self.databaseTimeout ? .on : .off,
                handler: { [unowned self] _ in
                    self.databaseTimeout = timeoutOption
                    refresh()
                    delegate?.didChangeDatabaseTimeout(timeoutOption, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }

    private func makeClipboardTimeoutMenu() -> UIMenu {
        let children = Settings.ClipboardTimeout.visibleValues.map { timeoutOption in
            UIAction(
                title: timeoutOption.fullTitle,
                state: timeoutOption == self.clipboardTimeout ? .on : .off,
                handler: { [unowned self] _ in
                    self.clipboardTimeout = timeoutOption
                    refresh()
                    delegate?.didChangeClipboardTimeout(timeoutOption, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }

    private func makeShakeActionMenu() -> UIMenu {
        let isAppLockDisabled = !Settings.current.isAppLockEnabled
        let actions = Settings.ShakeGestureAction.getVisibleValues().map { action in
            let isDisabled = (action == .lockApp) && isAppLockDisabled
            return UIAction(
                title: action.shortTitle,
                subtitle: isDisabled ? action.disabledSubtitle : nil,
                attributes: isDisabled ? [.disabled] : [],
                state: action == self.shakeAction ? .on : .off,
                handler: { [unowned self] _ in
                    self.shakeAction = action
                    refresh()
                    delegate?.didChangeShakeAction(action, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: actions)
    }
}
