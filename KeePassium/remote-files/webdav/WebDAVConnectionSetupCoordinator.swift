//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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

    func didPickRemoteFolder(
        _ folder: WebDAVItem,
        credential: NetworkCredential,
        stateIndicator: BusyStateIndicating?,
        in coordinator: WebDAVConnectionSetupCoordinator
    )
}

final class WebDAVConnectionSetupCoordinator: BaseCoordinator, RemoteConnectionSetupAlertPresenting {
    weak var delegate: WebDAVConnectionSetupCoordinatorDelegate?

    private let setupVC: WebDAVConnectionSetupVC
    private var selectionMode: RemoteItemSelectionMode
    private var credential: NetworkCredential?

    init(
        router: NavigationRouter,
        selectionMode: RemoteItemSelectionMode = .file
    ) {
        self.selectionMode = selectionMode
        self.setupVC = WebDAVConnectionSetupVC.make()
        super.init(router: router)
        setupVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(setupVC, animated: true)
    }

    private func showFolder(
        folder: WebDAVItem,
        credential: NetworkCredential,
        stateIndicator: BusyStateIndicating
    ) {
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
                _presenterForModals.showErrorAlert(remoteError)
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
        _router.push(vc, animated: true, onPop: nil)
    }
}

extension WebDAVConnectionSetupCoordinator: RemoteFolderViewerDelegate {
    func canSaveTo(folder: RemoteFileItem?, in viewController: RemoteFolderViewerVC) -> Bool {
        return folder != nil
    }

    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let credential else {
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

    func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let webDAVFolder = folder as? WebDAVItem,
              let credential else {
            assertionFailure()
            return
        }

        delegate?.didPickRemoteFolder(
            webDAVFolder,
            credential: credential,
            stateIndicator: viewController,
            in: self
        )
    }
}

extension WebDAVConnectionSetupCoordinator: WebDAVConnectionSetupVCDelegate {
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: WebDAVConnectionSetupVC
    ) {
        self.credential = credential

        if nakedWebdavURL.hasDirectoryPath {
            Diag.debug("Target URL has directory path")
            showFolder(
                folder: .root(url: nakedWebdavURL),
                credential: credential,
                stateIndicator: viewController
            )
            return
        }

        viewController.indicateState(isBusy: true)
        WebDAVManager.shared.checkIsFolder(
            url: nakedWebdavURL,
            credential: credential,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completionQueue: .main
        ) { [weak self, weak viewController] result in
            guard let self,
                  let viewController
            else { return }

            viewController.indicateState(isBusy: false)
            switch result {
            case .success(let isFolder):
                if isFolder {
                    Diag.debug("Target URL is a directory")
                    self.showFolder(
                        folder: .root(url: nakedWebdavURL),
                        credential: credential,
                        stateIndicator: viewController
                    )
                } else {
                    Diag.debug("Target URL is a file")
                    guard self.selectionMode == .file else {
                        viewController.showErrorAlert(
                            LString.Error.webDAVExportNeedsFolder,
                            title: LString.titleError
                        )
                        return
                    }
                    let prefixedURL = WebDAVFileURL.build(nakedURL: nakedWebdavURL)
                    self.checkAndPickWebDAVConnection(
                        url: prefixedURL,
                        credential: credential,
                        viewController: viewController
                    )
                }
            case .failure(let error):
                viewController.showErrorAlert(error)
            }
        }
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
                guard let self, let viewController else { return }
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
