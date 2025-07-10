//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AboutCoordinator: BaseCoordinator {
    private let aboutVC: AboutVC

    override init(router: NavigationRouter) {
        aboutVC = AboutVC.instantiateFromStoryboard()
        super.init(router: router)
        aboutVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(aboutVC, dismissButtonStyle: .close, animated: true)
    }
}

extension AboutCoordinator: AboutDelegate {

    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: AboutVC) {
        SupportEmailComposer.show(subject: .supportRequest, parent: viewController, popoverAnchor: popoverAnchor)
    }

    func didPressWriteReview(at popoverAnchor: PopoverAnchor, in viewController: AboutVC) {
        AppStoreHelper.writeReview()
    }

    func didPressOpenURL(_ url: URL, at popoverAnchor: PopoverAnchor, in viewController: AboutVC) {
        AppGroup.applicationShared?.open(url, options: [:], completionHandler: nil)
    }
}
