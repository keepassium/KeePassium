//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class SearchSettingsCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    internal let _searchSettingsVC: SearchSettingsVC
    private let settingsNotification: SettingsNotifications

    init(router: NavigationRouter) {
        self.router = router
        _searchSettingsVC = SearchSettingsVC()
        settingsNotification = SettingsNotifications()
        _searchSettingsVC.delegate = self
        settingsNotification.observer = self
    }

    deinit {
        settingsNotification.stopObserving()
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(_searchSettingsVC, animated: true, onPop: { [weak self] in
            guard let self else { return }
            removeAllChildCoordinators()
            dismissHandler?(self)
        })
        settingsNotification.startObserving()
        applySettingsToVC()
    }

    func refresh() {
        applySettingsToVC()
        _searchSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        let s = Settings.current
        _searchSettingsVC.isStartWithSearch = s.isStartWithSearch
        _searchSettingsVC.isSearchFieldNames = s.isSearchFieldNames
        _searchSettingsVC.isSearchProtectedValues = s.isSearchProtectedValues
        _searchSettingsVC.isSearchPasswords = s.isSearchPasswords
    }
}

extension SearchSettingsCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

extension SearchSettingsCoordinator: SearchSettingsVC.Delegate {
    func didChangeStartWithSearch(_ isOn: Bool, in viewController: SearchSettingsVC) {
        Settings.current.isStartWithSearch = isOn
        viewController.showNotificationIfManaged(setting: .startWithSearch)
        refresh()
    }

    func didChangeSearchFieldNames(_ isOn: Bool, in viewController: SearchSettingsVC) {
        Settings.current.isSearchFieldNames = isOn
        viewController.showNotificationIfManaged(setting: .searchFieldNames)
        refresh()
    }

    func didChangeSearchProtectedValues(_ isOn: Bool, in viewController: SearchSettingsVC) {
        Settings.current.isSearchProtectedValues = isOn
        viewController.showNotificationIfManaged(setting: .searchProtectedValues)
        refresh()
    }

    func didChangeSearchPasswords(_ isOn: Bool, in viewController: SearchSettingsVC) {
        Settings.current.isSearchPasswords = isOn
        viewController.showNotificationIfManaged(setting: .searchPasswords)
        refresh()
    }
}
