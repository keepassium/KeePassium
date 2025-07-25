//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AppHistoryCoordinator: BaseCoordinator {
    private let viewer: AppHistoryViewerVC

    override init(router: NavigationRouter) {
        viewer = AppHistoryViewerVC()
        super.init(router: router)
    }

    override func start() {
        super.start()
        AppHistory.load { [weak self] appHistory in
             self?.viewer.appHistory = self?.filter(appHistory: appHistory)
        }
        _pushInitialViewController(viewer, animated: true)
    }

    private func filter(appHistory: AppHistory?) -> AppHistory? {
        guard var appHistory else {
            return nil
        }

        let currentOS: AppHistory.Item.OS = ProcessInfo.isCatalystApp ? .macos : .ios

        let currentEdition: AppHistory.Item.Edition
        #if INTUNE
        currentEdition = .org
        #else
        switch BusinessModel.type {
        case .freemium:
            currentEdition = .free
        case .prepaid:
            currentEdition = .pro
        }
        #endif

        for i in 0..<appHistory.sections.count {
            appHistory.sections[i].items = appHistory.sections[i].items
                .filter({ $0.os.contains(currentOS) && $0.edition.contains(currentEdition) })
        }
        return appHistory
    }
}
