//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class HelpViewerCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    
    typealias DismissHandler = (HelpViewerCoordinator) -> Void
    var dismissHandler: DismissHandler?
    
    var article: HelpArticle?
    
    fileprivate var router: NavigationRouter
    private let helpViewerVC: HelpViewerVC
    
    init(router: NavigationRouter) {
        self.router = router
        
        helpViewerVC = HelpViewerVC.create()
        super.init()
        
        helpViewerVC.delegate = self
    }
    
    func start() {
        assert(article != nil)
        helpViewerVC.content = article
        router.push(helpViewerVC, animated: true, onPop: {
            [self] (viewController) in 
            self.dismissHandler?(self)
        })
    }
}

extension HelpViewerCoordinator: HelpViewerDelegate {
    func didPressCancel(in viewController: HelpViewerVC) {
        router.pop(animated: true)
    }
    
    func didPressShare(at popoverAnchor: PopoverAnchor, in viewController: HelpViewerVC) {
        guard let text = viewController.bodyLabel.attributedText else {
            assertionFailure()
            return
        }
        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil)
        popoverAnchor.apply(to: activityController.popoverPresentationController)
        viewController.present(activityController, animated: true)
    }
}
