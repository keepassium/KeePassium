//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

class BaseCoordinator: NSObject, Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()
    var _dismissHandler: CoordinatorDismissHandler?

    internal let _router: NavigationRouter
    internal var _initialViewController: UIViewController?
    private let settingsNotifications: SettingsNotifications

    init(router: NavigationRouter) {
        self._router = router
        settingsNotifications = SettingsNotifications()
        super.init()
        settingsNotifications.observer = self
        startObservingPremiumStatus(#selector(_premiumStatusDidChange))
    }

    deinit {
        settingsNotifications.stopObserving()
        assert(childCoordinators.isEmpty, "Some child coordinators were not released")
        removeAllChildCoordinators()
    }

    public func start() {
        settingsNotifications.startObserving()
    }

    public func refresh() {
    }

    internal var _presenterForModals: UIViewController {
        return _router.navigationController.presentedViewController ?? _router.navigationController
    }

    internal func _pushInitialViewController(
        _ viewController: UIViewController,
        replaceTopViewController: Bool = false,
        dismissButtonStyle: UIBarButtonItem.SystemItem? = nil,
        animated: Bool
    ) {
        _initialViewController = viewController
        if _router.navigationController.topViewController == nil,
           let dismissButtonStyle
        {
            let dismissButton = UIBarButtonItem(
                systemItem: dismissButtonStyle,
                primaryAction: UIAction { [weak self] _ in
                    self?.dismiss()
                }
            )
            viewController.navigationItem.leftBarButtonItem = dismissButton
        }
        _pushInitialViewController(
            viewController,
            to: _router,
            replaceTopViewController: replaceTopViewController,
            animated: animated
        )
    }

    internal func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        if let _initialViewController {
            _router.pop(viewController: _initialViewController, animated: animated, completion: completion)
        } else {
            _dismissHandler?(self)
            if _router.isEmpty {
                _router.dismiss(animated: animated, completion: completion)
            } else {
                completion?()
            }
        }
    }
}

extension BaseCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

extension BaseCoordinator {
    @objc internal func _premiumStatusDidChange() {
        refresh()
    }
}
