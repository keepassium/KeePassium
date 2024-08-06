//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DiagnosticsViewerCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    private var router: NavigationRouter
    private var diagnosticsViewerVC: DiagnosticsViewerVC

    init(router: NavigationRouter) {
        self.router = router
        diagnosticsViewerVC = DiagnosticsViewerVC.create()
        super.init()

        diagnosticsViewerVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        if router.navigationController.topViewController == nil {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            diagnosticsViewerVC.navigationItem.leftBarButtonItem = leftButton
        }
        router.push(diagnosticsViewerVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    @objc private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
}

extension DiagnosticsViewerCoordinator: DiagnosticsViewerDelegate {
    func didPressCopy(text: String, in diagnosticsViewer: DiagnosticsViewerVC) {
        Clipboard.general.copyWithoutExpiry(text)
        HapticFeedback.play(.copiedToClipboard)
        diagnosticsViewer.showNotification(LString.diagnosticLogCopiedToClipboard)
    }

    func didPressContactSupport(
        text: String,
        at popoverAnchor: PopoverAnchor,
        in diagnosticsViewer: DiagnosticsViewerVC
    ) {
        SupportEmailComposer.show(
            subject: .problem,
            parent: diagnosticsViewer,
            popoverAnchor: popoverAnchor) { [weak self] success in
            if !success {
                Diag.debug("Failed to create an email message, copying to clipboard instead")
                self?.didPressCopy(text: text, in: diagnosticsViewer)
            }
        }
    }
}
