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
    var dismissHandler: CoordinatorDismissHandler?
    
    var article: HelpArticle?
    
    fileprivate var router: NavigationRouter
    private let helpViewerVC: HelpViewerVC
    
    init(router: NavigationRouter) {
        self.router = router
        
        helpViewerVC = HelpViewerVC.create()
        super.init()
        
        helpViewerVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        assert(article != nil)
        helpViewerVC.content = article
        
        if router.navigationController.topViewController == nil {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            helpViewerVC.navigationItem.leftBarButtonItem = leftButton
        }
        
        router.push(helpViewerVC, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    @objc private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
}

extension HelpViewerCoordinator: HelpViewerDelegate {
    func didPressShare(at popoverAnchor: PopoverAnchor, in viewController: HelpViewerVC) {
        guard let text = viewController.bodyTextView.attributedText else {
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
