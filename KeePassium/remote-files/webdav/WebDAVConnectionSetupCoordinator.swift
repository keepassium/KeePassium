//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol WebDAVConnectionSetupCoordinatorDelegate: AnyObject {
    func didPickRemoteFile(
        url: URL,
        credential: NetworkCredential,
        in coordinator: WebDAVConnectionSetupCoordinator
    )
}

final class WebDAVConnectionSetupCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: WebDAVConnectionSetupCoordinatorDelegate?

    private let router: NavigationRouter
    private let setupVC: WebDAVConnectionSetupVC

    init(router: NavigationRouter) {
        self.router = router
        self.setupVC = WebDAVConnectionSetupVC.make()
        setupVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(setupVC, animated: true, onPop: { [weak self] in
            guard let self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    func dismiss() {
        router.pop(viewController: setupVC, animated: true)
    }
}

extension WebDAVConnectionSetupCoordinator: WebDAVConnectionSetupVCDelegate {
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: WebDAVConnectionSetupVC
    ) {
        let prefixedURL = WebDAVFileURL.build(nakedURL: nakedWebdavURL)
        checkAndPickWebDAVConnection(
            url: prefixedURL,
            credential: credential,
            viewController: viewController)
    }

    private func checkAndPickWebDAVConnection(
        url: URL,
        credential: NetworkCredential,
        viewController: WebDAVConnectionSetupVC
    ) {
        viewController.setState(isBusy: true)
        WebDAVManager.shared.getFileInfo(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completion: { [weak self, weak viewController] result in
                guard let self = self, let viewController = viewController else { return }
                viewController.setState(isBusy: false)
                switch result {
                case .success:
                    Diag.info("Remote file picked successfully")
                    self.delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
                    self.dismiss()
                case .failure(let fileAccessError):
                    Diag.error("Failed to access WebDAV file [message: \(fileAccessError.localizedDescription)]")
                    viewController.showErrorAlert(fileAccessError)
                }
            }
        )
    }
}
