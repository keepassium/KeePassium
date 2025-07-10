//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class SearchSettingsVC: BaseSettingsViewController<SearchSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didChangeStartWithSearch(_ isOn: Bool, in viewController: SearchSettingsVC)
        func didChangeSearchFieldNames(_ isOn: Bool, in viewController: SearchSettingsVC)
        func didChangeSearchProtectedValues(_ isOn: Bool, in viewController: SearchSettingsVC)
        func didChangeSearchPasswords(_ isOn: Bool, in viewController: SearchSettingsVC)
    }

    weak var delegate: (any Delegate)?
    var isStartWithSearch = false
    var isSearchFieldNames = false
    var isSearchProtectedValues = false
    var isSearchPasswords = false

    override init() {
        super.init()
        title = LString.searchSettingsTitle
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    enum Section: SettingsSection {
        case start
        case scope

        var header: String? {
            switch self {
            case .start:
                return nil
            case .scope:
                return LString.searchScopeTitle
            }
        }
        var footer: String? {
            switch self {
            case .start:
                return LString.startWithSearchDescription
            case .scope:
                return nil
            }
        }
    }

    override func refresh() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()

        snapshot.appendSections([.start])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.startWithSearchTitle,
                isOn: isStartWithSearch,
                handler: { [unowned self] itemConfig in
                    isStartWithSearch = itemConfig.isOn
                    refresh()
                    delegate?.didChangeStartWithSearch(isStartWithSearch, in: self)
                }
            )),
        ])

        snapshot.appendSections([.scope])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.searchInFieldNamesTitle,
                isOn: isSearchFieldNames,
                handler: { [unowned self] itemConfig in
                    isSearchFieldNames = itemConfig.isOn
                    refresh()
                    delegate?.didChangeSearchFieldNames(isSearchFieldNames, in: self)
                }
            )),
            .toggle(.init(
                title: LString.searchInProtectedValuesTitle,
                isOn: isSearchProtectedValues,
                handler: { [unowned self] itemConfig in
                    isSearchProtectedValues = itemConfig.isOn
                    refresh()
                    delegate?.didChangeSearchProtectedValues(isSearchProtectedValues, in: self)
                }
            )),
            .toggle(.init(
                title: LString.searchInPasswordsTitle,
                isEnabled: isSearchProtectedValues,
                isOn: isSearchPasswords,
                handler: { [unowned self] itemConfig in
                    isSearchPasswords = itemConfig.isOn
                    refresh()
                    delegate?.didChangeSearchPasswords(isSearchPasswords, in: self)
                }
            )),
        ])
        _dataSource.apply(snapshot, animatingDifferences: true)
    }
}
