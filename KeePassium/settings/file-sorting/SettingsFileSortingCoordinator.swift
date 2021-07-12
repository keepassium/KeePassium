//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class SettingsFileSortingCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    
    var dismissHandler: CoordinatorDismissHandler?
    
    private let router: NavigationRouter
    
    private lazy var viewController: SettingsFileSortingVC = {
        let vc = SettingsFileSortingVC.instantiateFromStoryboard()
        vc.delegate = self
        return vc
    }()
    
    private lazy var settingsNotifications: SettingsNotifications = {
        let notifications = SettingsNotifications()
        notifications.observer = self
        return notifications
    }()
    
    init(router: NavigationRouter) {
        self.router = router
    }
    
    deinit {
        settingsNotifications.stopObserving()
        
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDoneButton(in: viewController)
        router.push(viewController, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        settingsNotifications.startObserving()
    }
    
    private func setupDoneButton(in viewController: UIViewController) {
        guard router.navigationController.topViewController == nil else {
            return
        }
        
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(didPressDismiss))
        viewController.navigationItem.rightBarButtonItem = doneButton
    }
    
    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        router.dismiss(animated: true)
    }
}

extension SettingsFileSortingCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        viewController.refresh()
    }
}

extension SettingsFileSortingCoordinator: SettingsFileSortingDelegate {
    func didChangeSortOrder(
        sortOrder: Settings.FilesSortOrder,
        in viewCoordinator: SettingsFileSortingVC
    ) {
        Settings.current.filesSortOrder = sortOrder
    }
    
    func didChangeBackupVisibility(
        isBackupVisible: Bool,
        in viewCoordinator: SettingsFileSortingVC
    ) {
        Settings.current.isBackupFilesVisible = isBackupVisible
    }
}
