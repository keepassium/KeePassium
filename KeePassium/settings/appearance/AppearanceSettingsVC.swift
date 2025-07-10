//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class AppearanceSettingsVC: BaseSettingsViewController<AppearanceSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didPressChangeAppIcon(in viewController: AppearanceSettingsVC)
        func didPressChangeDatabaseIcons(in viewController: AppearanceSettingsVC)
        func didToggleOpenLastUsedTab(_ isOn: Bool, in viewController: AppearanceSettingsVC)
        func didChangeTextScale(_ textScale: Float, in viewController: AppearanceSettingsVC)
        func didPressFontPicker(in viewController: AppearanceSettingsVC)
        func didPressRestoreDefaults(in viewController: AppearanceSettingsVC)
        func didToggleHidePasswords(_ isOn: Bool, in viewController: AppearanceSettingsVC)
    }

    weak var delegate: Delegate?
    var isSupportsAlternateIcons = false
    var databaseIconSet: DatabaseIconSet = .keepassium
    var isOpenLastUsedTab = false
    var textScale: Float = 1.0
    var entryTextFontDescriptor: UIFontDescriptor?
    var isHidePasswords = false

    override init() {
        super.init()
        title = LString.appearanceSettingsTitle
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>
    enum Section: SettingsSection {
        case icons
        case entryViewer
        case protectedFields

        var header: String? {
            switch self {
            case .entryViewer:
                return LString.appearanceEntryViewerTitle
            case .protectedFields:
                return LString.protectedFieldsTitle
            default:
                return nil
            }
        }

        var footer: String? {
            switch self {
            case .protectedFields:
                return LString.hidePasswordsDescription
            default:
                return nil
            }
        }
    }

    override func refresh() {
        var snapshot = Snapshot()

        snapshot.appendSections([.icons])
        if isSupportsAlternateIcons {
            snapshot.appendItems([
                .basic(.init(
                    title: LString.appearanceAppIconTitle,
                    image: .symbol(.atom),
                    fixedAccessories: [.disclosureIndicator()],
                    handler: { [unowned self] in
                        delegate?.didPressChangeAppIcon(in: self)
                    }
                )),
            ])
        }
        snapshot.appendItems([
            .basic(.init(
                title: LString.appearanceDatabaseIconsTitle,
                image: databaseIconSet.getIcon(.key),
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressChangeDatabaseIcons(in: self)
                }
            )),
        ])

        snapshot.appendSections([.entryViewer])
        let isDefaultFont = entryTextFontDescriptor == nil
        let isDefaultSize = abs(textScale - 1.0).isLessThanOrEqualTo(.ulpOfOne)
        let entryTextFont = UIFont.monospaceFont(descriptor: entryTextFontDescriptor, style: .body)
        snapshot.appendItems([
            .toggle(.init(
                title: LString.appearanceOpenLastUsedTabTitle,
                isOn: isOpenLastUsedTab,
                handler: { [unowned self] itemConfig in
                    self.isOpenLastUsedTab = itemConfig.isOn
                    refresh()
                    delegate?.didToggleOpenLastUsedTab(itemConfig.isOn, in: self)
                }
            )),
            .textScale(.init(
                title: LString.appearanceTextSizeTitle,
                value: textScale,
                font: entryTextFont,
                handler: { [unowned self] itemConfig in
                    self.textScale = itemConfig.value
                    refresh()
                    delegate?.didChangeTextScale(itemConfig.value, in: self)
                }
            )),
            .basic(.init(
                title: LString.appearanceFontTitle,
                subtitle: isDefaultFont ? LString.appearanceFontDefaultTitle : entryTextFont.familyName,
                decorators: [.value],
                fixedAccessories: [.disclosureIndicator()],
                handler: { [unowned self] in
                    delegate?.didPressFontPicker(in: self)
                }
            )),
            .basic(.init(
                title: LString.actionRestoreDefaults,
                isEnabled: (!isDefaultFont || !isDefaultSize),
                decorators: [.action],
                handler: { [unowned self] in
                    delegate?.didPressRestoreDefaults(in: self)
                }
            )),
        ])

        snapshot.appendSections([.protectedFields])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.hidePasswordsTitle,
                isOn: isHidePasswords,
                handler: { [unowned self] itemConfig in
                    self.isHidePasswords = itemConfig.isOn
                    refresh()
                    delegate?.didToggleHidePasswords(itemConfig.isOn, in: self)
                }
            )),
        ])
        _dataSource.apply(snapshot, animatingDifferences: false)
    }
}
