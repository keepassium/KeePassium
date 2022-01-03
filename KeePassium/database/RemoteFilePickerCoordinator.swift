//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol RemoteFilePickerCoordinatorDelegate: AnyObject {
    func didPickRemoteFile(
        url: URL,
        credential: NetworkCredential,
        in coordinator: RemoteFilePickerCoordinator
    )
}

final class RemoteFilePickerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    weak var delegate: RemoteFilePickerCoordinatorDelegate?
    
    private let router: NavigationRouter
    private let viewController: RemoteFilePickerVC
    
    init(router: NavigationRouter) {
        self.router = router
        viewController = RemoteFilePickerVC.make()
        viewController.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDismissButton()
        router.push(viewController, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    private func setupDismissButton() {
        guard router.navigationController.topViewController == nil else {
            return
        }
        
        let cancelButton = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction() { [weak self] _ in
                self?.dismiss()
            },
            menu: nil)
        viewController.navigationItem.leftBarButtonItem = cancelButton
    }

    private func dismiss() {
        router.pop(viewController: viewController, animated: true)
    }
}

extension RemoteFilePickerCoordinator: RemoteFilePickerDelegate {
    func didPressDone(
        url: URL,
        credential: NetworkCredential,
        in viewController: RemoteFilePickerVC
    ) {
        let prefixedURL = url.withSchemePrefix(WebDAVDataSource.urlSchemePrefix)
        checkAndPickConnection(url: prefixedURL, credential: credential)
    }
    
    private func checkAndPickConnection(
        url: URL,
        credential: NetworkCredential
    ) {
        viewController.showBusy(true)
        WebDAVManager.shared.getFileInfo(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: FileDataProvider.defaultTimeout,
            completion: { [weak self] result in
                guard let self = self else { return }
                self.viewController.showBusy(false)
                switch result {
                case .success(_):
                    Diag.info("Remote file picked successfully")
                    self.delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
                    self.dismiss()
                case .failure(let fileAccessError):
                    Diag.error("Failed to access WebDAV file [message: \(fileAccessError.localizedDescription)]")
                    self.viewController.showErrorAlert(fileAccessError)
                }
            }
        )
    }
}
