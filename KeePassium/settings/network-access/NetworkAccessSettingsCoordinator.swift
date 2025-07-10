//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class NetworkAccessSettingsCoordinator: BaseCoordinator {
    private let viewController: NetworkAccessSettingsVC

    override init(router: NavigationRouter) {
        viewController = NetworkAccessSettingsVC.make()
        super.init(router: router)

        viewController.isAccessAllowed = Settings.current.isNetworkAccessAllowed
        viewController.isAutoDownloadEnabled = Settings.current.isAutoDownloadFaviconsEnabled
        viewController.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(viewController, animated: true)
    }
}

extension NetworkAccessSettingsCoordinator: NetworkAccessSettingsDelegate {
    func didPressOpenURL(_ url: URL, in viewController: NetworkAccessSettingsVC) {
        URLOpener(viewController).open(url: url)
    }

    func didChangeNetworkPermission(isAllowed: Bool, in viewController: NetworkAccessSettingsVC) {
        Settings.current.isNetworkAccessAllowed = isAllowed
        viewController.showNotificationIfManaged(setting: .networkAccessAllowed)
        viewController.isAccessAllowed = Settings.current.isNetworkAccessAllowed
        viewController.refreshImmediately()
    }

    func didChangeAutoDownloadFavicons(isEnabled: Bool, in viewController: NetworkAccessSettingsVC) {
        Settings.current.isAutoDownloadFaviconsEnabled = isEnabled

        let wasChangeAccepted = (Settings.current.isAutoDownloadFaviconsEnabled == isEnabled)
        if !wasChangeAccepted {
            viewController.showManagedSettingNotification()
        }
        viewController.isAutoDownloadEnabled = Settings.current.isAutoDownloadFaviconsEnabled
        viewController.refresh()
    }
}
