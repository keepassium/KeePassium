//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DiagnosticsViewerCoordinator: BaseCoordinator {
    private var diagnosticsViewerVC: DiagnosticsViewerVC

    override init(router: NavigationRouter) {
        diagnosticsViewerVC = DiagnosticsViewerVC.create()
        super.init(router: router)
        diagnosticsViewerVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(diagnosticsViewerVC, dismissButtonStyle: .cancel, animated: true)
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
