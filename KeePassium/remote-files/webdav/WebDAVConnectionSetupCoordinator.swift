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
    private var firstVC: UIViewController?
    private var selectionMode: RemoteItemSelectionMode
    private var credential: NetworkCredential?

    init(
        router: NavigationRouter,
        selectionMode: RemoteItemSelectionMode = .file
    ) {
        self.router = router
        self.selectionMode = selectionMode
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

    private func showFolder(folder: WebDAVItem, credential: NetworkCredential, stateIndicator: BusyStateIndicating) {
        stateIndicator.indicateState(isBusy: true)
        WebDAVManager.shared.getItems(
            in: folder,
            credential: credential,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completionQueue: .main
        ) { [weak self, weak stateIndicator] result in
            guard let self else { return }
            stateIndicator?.indicateState(isBusy: false)
            switch result {
            case .success(let items):
                showFolder(items: items, parent: folder, title: folder.name)
            case .failure(let remoteError):
                showErrorAlert(remoteError)
            }
        }
    }

    private func showFolder(
        items: [WebDAVItem],
        parent: WebDAVItem?,
        title: String
    ) {
        let vc = RemoteFolderViewerVC.make()
        vc.folder = parent
        vc.items = items
        vc.folderName = title
        vc.delegate = self
        vc.selectionMode = selectionMode
        if self.firstVC == nil {
            self.firstVC = vc
        }
        router.push(vc, animated: true, onPop: nil)
    }

    private func showErrorAlert(_ error: Error) {
        router.navigationController.showErrorAlert(error)
    }
}

extension WebDAVConnectionSetupCoordinator: RemoteFolderViewerDelegate {
    func canSaveTo(folder: RemoteFileItem?, in viewController: RemoteFolderViewerVC) -> Bool {
        return false
    }

    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let credential = credential else {
            Diag.warning("Not signed into WebDav, cancelling")
            assertionFailure()
            return
        }

        guard let webDAVItem = item as? WebDAVItem else {
            Diag.warning("Unexpected type of selected item")
            assertionFailure()
            return
        }

        if item.isFolder {
            showFolder(folder: webDAVItem, credential: credential, stateIndicator: viewController)
            return
        }

        let prefixedURL = WebDAVFileURL.build(nakedURL: webDAVItem.url)
        checkAndPickWebDAVConnection(
              url: prefixedURL,
              credential: credential,
              viewController: viewController)
    }

    func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {}
}

extension WebDAVConnectionSetupCoordinator: WebDAVConnectionSetupVCDelegate {
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: WebDAVConnectionSetupVC
    ) {
        self.credential = credential
        showFolder(folder: .root(url: nakedWebdavURL), credential: credential, stateIndicator: viewController)
    }

    private func checkAndPickWebDAVConnection(
        url: URL,
        credential: NetworkCredential,
        viewController: UIViewController & BusyStateIndicating
    ) {
        viewController.indicateState(isBusy: true)
        WebDAVManager.shared.getFileInfo(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completion: { [weak self, weak viewController] result in
                guard let self = self, let viewController = viewController else { return }
                viewController.indicateState(isBusy: false)
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
