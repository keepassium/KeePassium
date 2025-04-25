//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication.LABiometryType

final class AppProtectionSettingsVC: UIViewController {
    protocol Delegate: AnyObject {
        func didChangeAppProtectionEnabled(_ isEnabled: Bool, in viewController: AppProtectionSettingsVC)
        func didPressChangePasscode(in viewController: AppProtectionSettingsVC)
        func didChangeIsUseBiometric(_ isUseBiometric: Bool, in viewController: AppProtectionSettingsVC)
        func didChangeTimeout(_ timeout: Settings.AppLockTimeout, in viewController: AppProtectionSettingsVC)
        func didChangeIsLockOnAppLaunch(_ isLockOnAppLaunch: Bool, in viewController: AppProtectionSettingsVC)
        func didChangeIsLockOnFailedPasscode(
            _ isLockOnFailedPasscode: Bool,
            in viewController: AppProtectionSettingsVC)
    }

    weak var delegate: (any Delegate)?
    var isBiometricsSupported = false
    var biometryType: LABiometryType?
    var isAppProtectionEnabled: Bool = false
    var isUseBiometric: Bool = false
    var timeout: Settings.AppLockTimeout = .immediately
    var isLockOnAppLaunch: Bool = false
    var isLockOnFailedPasscode: Bool = false

    enum Section: Int, CaseIterable {
        case general
        case biometric
        case timeout
        case lockOnLaunch
        case wrongPasscode

        var header: String? {
            return nil
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
            case .wrongPasscode:
                return LString.lockOnWrongPasscodeDescription
            }
        }
    }

    internal var _collectionView: UICollectionView!
    internal var _dataSource: UICollectionViewDiffableDataSource<Section, SettingsItem>!

    init() {
        super.init(nibName: nil, bundle: nil)
        title = LString.titleAppProtectionSettings
        view.backgroundColor = .systemBackground
        _setupCollectionView()
        _setupDataSource()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func refresh() {
        guard isViewLoaded else { return }
        applySnapshot()
    }
}

extension AppProtectionSettingsVC {
    private func applySnapshot() {
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
                    applySnapshot()
                    delegate?.didChangeAppProtectionEnabled(isAppProtectionEnabled, in: self)
                }
            )),
            .navigation(.init(
                title: LString.actionChangePasscode,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                isButton: true,
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
                    applySnapshot()
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

        snapshot.appendSections([Section.lockOnLaunch])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.lockAppOnLaunchTitle,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                isOn: isLockOnAppLaunch,
                handler: { [unowned self] itemConfig in
                    isLockOnAppLaunch = itemConfig.isOn
                    applySnapshot()
                    delegate?.didChangeIsLockOnAppLaunch(isLockOnAppLaunch, in: self)
                }
            ))
        ])

        snapshot.appendSections([Section.wrongPasscode])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.lockOnWrongPasscodeTitle,
                image: nil,
                isEnabled: isAppProtectionEnabled,
                isOn: isLockOnFailedPasscode,
                handler: { [unowned self] itemConfig in
                    isLockOnFailedPasscode = itemConfig.isOn
                    applySnapshot()
                    delegate?.didChangeIsLockOnFailedPasscode(isLockOnFailedPasscode, in: self)
                }
            ))
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
                    applySnapshot()
                    delegate?.didChangeTimeout(timeoutOption, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }
}

extension AppProtectionSettingsVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performPrimaryActionForItemAt indexPath: IndexPath
    ) {
        let targetItem = _dataSource.itemIdentifier(for: indexPath)
        switch targetItem {
        case .navigation(let itemConfig):
            itemConfig.handler?()
        case .toggle, .picker, .none:
            return
        }
    }
}
