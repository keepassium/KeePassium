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
    private let connectionTypePicker: ConnectionTypePickerVC
    
    private struct OneDriveAccount {
        var driveInfo: OneDriveDriveInfo
        var token: OAuthToken
        
        var isCorporateAccount: Bool {
            switch driveInfo.type {
            case .personal:
                return false
            case .business, .sharepoint:
                return true
            }
        }
    }
    private var oneDriveAccount: OneDriveAccount?

    init(connectionType: RemoteConnectionType?, router: NavigationRouter) {
        self.router = router

        connectionTypePicker = ConnectionTypePickerVC.make()
        connectionTypePicker.selectedValue = nil 
        connectionTypePicker.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDismissButton()
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
        router.push(connectionTypePicker, animated: true, onPop: { [weak self] in
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
        connectionTypePicker.navigationItem.leftBarButtonItem = cancelButton
    }

    private func dismiss() {
        router.pop(viewController: connectionTypePicker, animated: true)
    }
    
    @objc
    private func premiumStatusDidChange() {
        connectionTypePicker.refresh()
    }
    
    private func showSourceSelector(connectionType: RemoteConnectionType) {
        let sourceSelectorVC = RemoteFilePickerVC.make()
        sourceSelectorVC.delegate = self
        sourceSelectorVC.connectionType = connectionType
        router.push(sourceSelectorVC, animated: true, onPop: { [weak self] in
            self?.oneDriveAccount = nil
        })
    }
}

extension RemoteFilePickerCoordinator: RemoteFilePickerDelegate {
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: RemoteFilePickerVC
    ) {
        let prefixedURL = WebDAVFileURL.build(nakedURL: nakedWebdavURL)
        checkAndPickWebDAVConnection(
            url: prefixedURL,
            credential: credential,
            viewController: viewController)
    }
    
    func didPressLoginToOneDrive(privateSession: Bool, in viewController: RemoteFilePickerVC) {
        startOneDriveSignIn(privateSession: privateSession, viewController: viewController)
    }
}

extension RemoteFilePickerCoordinator: ConnectionTypePickerDelegate {
    
    func willSelect(
        connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) -> Bool {
        if connectionType.isPremiumUpgradeRequired {
            offerPremiumUpgrade(for: .canUseBusinessClouds, in: viewController)
            return false
        }
        return true
    }
    
    func didSelect(connectionType: RemoteConnectionType, in viewController: ConnectionTypePickerVC) {
        showSourceSelector(connectionType: connectionType)
    }
}

extension RemoteFilePickerCoordinator {
    
    private func checkAndPickWebDAVConnection(
        url: URL,
        credential: NetworkCredential,
        viewController: RemoteFilePickerVC
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
                case .success(_):
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
    
    private func startOneDriveSignIn(privateSession: Bool, viewController: RemoteFilePickerVC) {
        viewController.setState(isBusy: true)
        OneDriveManager.shared.authenticate(
            presenter: viewController,
            privateSession: privateSession
        ) {
            [weak self, weak viewController] result in
            guard let self = self, let viewController = viewController else { return }
            self.oneDriveAccount = nil
            viewController.setState(isBusy: false)
            switch result {
            case .success(let token):
                self.startAddingOneDriveFile(token: token, viewController: viewController)
            case .failure(let oneDriveError):
                switch oneDriveError {
                case .cancelledByUser: 
                    break
                default:
                    viewController.showErrorAlert(oneDriveError)
                }
            }
        }
    }
}

extension RemoteFilePickerCoordinator {
    private func startAddingOneDriveFile(token: OAuthToken, viewController: RemoteFilePickerVC) {
        OneDriveManager.shared.getDriveInfo(parent: nil, freshToken: token) {
            [weak self, weak viewController] result in
            guard let self = self, let viewController = viewController else { return }
            switch result {
            case .success(let driveInfo):
                self.oneDriveAccount = OneDriveAccount(
                    driveInfo: driveInfo,
                    token: token
                )
                if driveInfo.type == .personal {
                    self.showOneDriveFolder(folder: nil, presenter: viewController)
                } else {
                    self.performPremiumActionOrOfferUpgrade(
                        for: .canUseBusinessClouds,
                        allowBypass: true,
                        bypassTitle: LString.actionIgnoreAndContinue,
                        in: viewController
                    ) { [weak self, weak presenter = viewController] in
                        guard let self = self, let presenter = presenter else { return }
                        self.showOneDriveFolder(folder: nil, presenter: presenter)
                    }
                }
            case .failure(let oneDriveError):
                viewController.showErrorAlert(oneDriveError)
            }
        }
    }
    
    private func showOneDriveFolder(folder: OneDriveFileItem?, presenter: UIViewController) {
        guard let oneDriveAccount = oneDriveAccount else {
            Diag.warning("Not signed into any OneDrive account")
            assertionFailure()
            return
        }
        let folderName = folder?.fileInfo.fileName ?? oneDriveAccount.driveInfo.type.description
        OneDriveManager.shared.getItems(
            in: folder?.itemPath ?? "/",
            parent: folder?.parent,
            token: oneDriveAccount.token,
            tokenUpdater: nil 
        ) {
            [weak self, weak presenter] result in
            guard let self = self else { return }
            switch result {
            case .success(let items):
                let vc = RemoteFolderViewerVC.make()
                vc.items = items
                vc.folderName = folderName
                vc.delegate = self
                self.router.push(vc, animated: true, onPop: {
                    
                })
            case .failure(let oneDriveError):
                presenter?.showErrorAlert(oneDriveError)
            }
        }
    }
    
    private func didSelectOneDriveFile(
        _ fileItem: OneDriveFileItem,
        oneDriveAccount: OneDriveAccount
    ) {
        let fileURL = OneDriveFileURL.build(from: fileItem, driveInfo: oneDriveAccount.driveInfo)
        let credential = NetworkCredential(oauthToken: oneDriveAccount.token)
        delegate?.didPickRemoteFile(url: fileURL, credential: credential, in: self)
        dismiss()
    }
}

extension RemoteFilePickerCoordinator: RemoteFolderViewerDelegate {
    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let oneDriveAccount = oneDriveAccount else {
            Diag.warning("Not signed into any OneDrive account")
            assertionFailure()
            return
        }
        guard let oneDriveFileItem = item as? OneDriveFileItem else {
            Diag.warning("Unexpected type of selected item")
            assertionFailure()
            return
        }

        if oneDriveFileItem.isFolder {
            showOneDriveFolder(folder: oneDriveFileItem, presenter: viewController)
            return
        }
        
        if oneDriveAccount.isCorporateAccount {
            performPremiumActionOrOfferUpgrade(for: .canUseBusinessClouds, in: viewController) {
                [weak self] in
                self?.didSelectOneDriveFile(oneDriveFileItem, oneDriveAccount: oneDriveAccount)
            }
        } else {
            didSelectOneDriveFile(oneDriveFileItem, oneDriveAccount: oneDriveAccount)
        }
    }
}
