//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication.LABiometryType

final class MainSettingsVC: BaseSettingsViewController<MainSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didPressShowAppHistory(in viewController: MainSettingsVC)

        func didPressUpgradeToPremium(in viewController: MainSettingsVC)
        func didPressManageSubscription(in viewController: MainSettingsVC)

        func didToggleAutoOpenPreviousDatabase(_ isOn: Bool, in viewController: MainSettingsVC)

        func didPressAppearanceSettings(in viewController: MainSettingsVC)
        func didPressSearchSettings(in viewController: MainSettingsVC)
        func didPressAutoFillSettings(in viewController: MainSettingsVC)
        func didPressAppProtectionSettings(in viewController: MainSettingsVC)
        func didPressDataProtectionSettings(in viewController: MainSettingsVC)
        func didPressNetworkAccessSettings(in viewController: MainSettingsVC)
        func didPressBackupSettings(in viewController: MainSettingsVC)

        func didPressShowDiagnostics(in viewController: MainSettingsVC)
        func didPressContactSupport(in viewController: MainSettingsVC)
        func didPressDonations(in viewController: MainSettingsVC)
        func didPressAboutApp(in viewController: MainSettingsVC)
    }

    weak var delegate: Delegate?
    var premiumState: SettingsPremiumState = .free(description: nil)
    var isAppProtectionVisible = true
    var isAutoOpenPreviousDatabase = false
    var biometryType: LABiometryType?
    var isNetworkAccessAllowed = false

    override init() {
        super.init()
        title = LString.titleSettings
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>
    enum Section: SettingsSection {
        case appHistory
        case premium(footer: String?)
        case start
        case various
        case accessControl
        case network
        case backup
        case support

        var header: String? {
            switch self {
            case .premium:
                return LString.settingsPremiumSectionTitle
            case .start:
                return LString.settingsStartSectionTitle
            case .accessControl:
                return LString.settingsAccessControlTitle
            case .network:
                return nil
            case .backup:
                return nil
            case .support:
                return LString.settingsSupportSectionTitle
            default:
                return nil
            }
        }

        var footer: String? {
            switch self {
            case .premium(let footer):
                return footer
            default:
                return nil
            }
        }
    }

    override func refresh() {
        var snapshot = Snapshot()

        snapshot.appendSections([.appHistory])
        snapshot.appendItems([
            .basic(.init(
                title: LString.titleAppHistory,
                image: .symbol(.newspaper),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressShowAppHistory(in: self)
                }
            )),
        ])

        configurePremiumSection(premiumState, snapshot: &snapshot)

        snapshot.appendSections([.start])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.autoOpenPreviousDatabase,
                image: .symbol(.autoStartStop),
                isOn: isAutoOpenPreviousDatabase,
                handler: { [unowned self] itemConfig in
                    self.isAutoOpenPreviousDatabase = itemConfig.isOn
                    refresh()
                    delegate?.didToggleAutoOpenPreviousDatabase(itemConfig.isOn, in: self)
                }
            )),
        ])

        snapshot.appendSections([.various])
        snapshot.appendItems([
            .basic(.init(
                title: LString.appearanceSettingsTitle,
                image: .symbol(.paintbrush),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressAppearanceSettings(in: self)
                }
            )),
            .basic(.init(
                title: LString.autoFillSettingsTitle,
                image: .symbol(.autoFill),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressAutoFillSettings(in: self)
                }
            )),
            .basic(.init(
                title: LString.searchSettingsTitle,
                image: .symbol(.magnifyingGlass),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressSearchSettings(in: self)
                }
            )),
        ])

        snapshot.appendSections([.accessControl])
        if isAppProtectionVisible {
            snapshot.appendItems([
                .basic(.init(
                    title: LString.titleAppProtectionSettings,
                    subtitle: getAppProtectionSubtitle(),
                    image: .symbol(.appProtection),
                    fixedAccessories: [.disclosureIndicator()],
                    handler: { [unowned self] in
                        delegate?.didPressAppProtectionSettings(in: self)
                    }
                )),
            ])
        }
        snapshot.appendItems([
            .basic(.init(
                title: LString.dataProtectionSettingsTitle,
                subtitle: LString.dataProtectionSettingsSubtitle,
                image: .symbol(.lock),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressDataProtectionSettings(in: self)
                }
            )),
        ])

        snapshot.appendSections([.network])
        snapshot.appendItems([
            .basic(.init(
                title: LString.titleNetworkAccessSettings,
                subtitle: isNetworkAccessAllowed ? LString.statusFeatureOn : LString.statusFeatureOff,
                image: .symbol(.network),
                decorators: [.value],
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressNetworkAccessSettings(in: self)
                }
            )),
        ])

        snapshot.appendSections([.backup])
        snapshot.appendItems([
            .basic(.init(
                title: LString.databaseBackupSettingsTitle,
                image: .symbol(.clockArrowCirclepath),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressBackupSettings(in: self)
                }
            )),
        ])

        snapshot.appendSections([.support])
        snapshot.appendItems([
            .basic(.init(
                title: LString.actionContactUs,
                subtitle: LString.contactUsSubtitle,
                image: .symbol(.at),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressContactSupport(in: self)
                }
            )),
            .basic(.init(
                title: LString.tipBoxTitle2,
                subtitle: LString.tipBoxTitle3,
                image: .symbol(.heart, tint: .red),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressDonations(in: self)
                }
            )),
            .basic(.init(
                title: LString.titleDiagnosticLog,
                subtitle: LString.diagnosticLogSubtitle,
                image: .symbol(.waveformPathEcg),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressShowDiagnostics(in: self)
                }
            )),
            .basic(.init(
                title: LString.aboutKeePassiumTitle,
                image: .symbol(.infoCircle),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressAboutApp(in: self)
                }
            )),
        ])
        _dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func getAppProtectionSubtitle() -> String {
        if let biometryTypeName = biometryType?.name {
            return String.localizedStringWithFormat(
                LString.appLockWithBiometricsSubtitleTemplate,
                biometryTypeName)
        } else {
            return LString.appLockWithPasscodeSubtitle
        }
    }

    private func configurePremiumSection(_ premiumState: SettingsPremiumState, snapshot: inout Snapshot) {
        switch premiumState {
        case .prepaid:
            return
        case .free(let description):
            snapshot.appendSections([.premium(footer: description)])
            snapshot.appendItems([
                .basic(.init(
                    title: LString.actionUpgradeToPremium,
                    image: .premiumBadge,
                    fixedAccessories: [.disclosureIndicator()],
                    handler: { [unowned self] in
                        delegate?.didPressUpgradeToPremium(in: self)
                    }
                )),
            ])
        case .fallback(let description):
            snapshot.appendSections([.premium(footer: nil)])
            snapshot.appendItems([
                .basic(.init(
                    title: LString.premiumVersion,
                    subtitle: description,
                    image: .symbol(.checkmarkSeal),
                    fixedAccessories: [.disclosureIndicator()],
                    handler: { [unowned self] in
                        delegate?.didPressUpgradeToPremium(in: self)
                    }
                )),
            ])
        case let .active(description, isSubscription):
            snapshot.appendSections([.premium(footer: nil)])
            snapshot.appendItems([
                .basic(.init(
                    title: LString.premiumVersion,
                    subtitle: description,
                    image: .symbol(.checkmarkSeal),
                    fixedAccessories: [.disclosureIndicator()],
                    handler: { [unowned self] in
                        delegate?.didPressUpgradeToPremium(in: self)
                    }
                )),
            ])
            if isSubscription {
                snapshot.appendItems([
                    .basic(.init(
                        title: LString.actionManageSubscriptions,
                        image: .symbol(.gearshape),
                        fixedAccessories: [.disclosureIndicator()],
                        handler: { [unowned self] in
                            delegate?.didPressManageSubscription(in: self)
                        }
                    )),
                ])
            }
        }
    }
}
