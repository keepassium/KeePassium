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
    private let sourceSelectorVC: RemoteFilePickerVC
    private var connectionTypePickerVC: ConnectionTypePickerVC?
    private var currentConnectionType: RemoteConnectionType

    private struct OneDriveAccount {
        var driveInfo: OneDriveDriveInfo
        var token: OAuthToken
    }
    private var oneDriveAccount: OneDriveAccount?

    init(router: NavigationRouter) {
        self.router = router
        currentConnectionType = Settings.current.lastRemoteConnectionType ?? .webdav

        sourceSelectorVC = RemoteFilePickerVC.make()
        sourceSelectorVC.delegate = self
        sourceSelectorVC.connectionType = currentConnectionType
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        setupDismissButton()
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
        router.push(sourceSelectorVC, animated: true, onPop: { [weak self] in
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
        sourceSelectorVC.navigationItem.leftBarButtonItem = cancelButton
    }

    private func dismiss() {
        router.pop(viewController: sourceSelectorVC, animated: true)
    }
    
    @objc
    private func premiumStatusDidChange() {
        connectionTypePickerVC?.refresh()
    }
}

extension RemoteFilePickerCoordinator: RemoteFilePickerDelegate {
    func didPressSelectConnectionType(
        at popoverAnchor: PopoverAnchor,
        in viewController: RemoteFilePickerVC
    ) {
        showConnectionTypeSelector(at: popoverAnchor)
    }
    
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: RemoteFilePickerVC
    ) {
        let prefixedURL = WebDAVFileURL.build(nakedURL: nakedWebdavURL)
        checkAndPickWebDAVConnection(url: prefixedURL, credential: credential)
    }
    
    func didPressLoginToOneDrive(privateSession: Bool, in viewController: RemoteFilePickerVC) {
        startOneDriveSignIn(privateSession: privateSession)
    }
}

extension RemoteFilePickerCoordinator: ConnectionTypePickerDelegate {
    private func showConnectionTypeSelector(at popoverAnchor: PopoverAnchor) {
        let pickerVC = ConnectionTypePickerVC.make()
        pickerVC.selectedValue = currentConnectionType
        pickerVC.delegate = self
        router.push(pickerVC, animated: true, onPop: { [weak self] in
            self?.connectionTypePickerVC = nil
        })
        self.connectionTypePickerVC = pickerVC
    }
    
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
        currentConnectionType = connectionType
        Settings.current.lastRemoteConnectionType = connectionType
        sourceSelectorVC.connectionType = connectionType
        router.pop(viewController: viewController, animated: true)
    }
}

extension RemoteFilePickerCoordinator {
    
    private func checkAndPickWebDAVConnection(
        url: URL,
        credential: NetworkCredential
    ) {
        sourceSelectorVC.setState(isBusy: true)
        WebDAVManager.shared.getFileInfo(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: FileDataProvider.defaultTimeout,
            completion: { [weak self] result in
                guard let self = self else { return }
                self.sourceSelectorVC.setState(isBusy: false)
                switch result {
                case .success(_):
                    Diag.info("Remote file picked successfully")
                    self.delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
                    self.dismiss()
                case .failure(let fileAccessError):
                    Diag.error("Failed to access WebDAV file [message: \(fileAccessError.localizedDescription)]")
                    self.sourceSelectorVC.showErrorAlert(fileAccessError)
                }
            }
        )
    }
    
    private func startOneDriveSignIn(privateSession: Bool) {
        sourceSelectorVC.setState(isBusy: true)
        OneDriveManager.shared.authenticate(
            presenter: sourceSelectorVC,
            privateSession: privateSession
        ) {
            [weak self] result in
            guard let self = self else { return }
            self.oneDriveAccount = nil
            self.sourceSelectorVC.setState(isBusy: false)
            switch result {
            case .success(let token):
                self.startAddingOneDriveFile(token: token)
            case .failure(let oneDriveError):
                switch oneDriveError {
                case .cancelledByUser: 
                    break
                default:
                    self.sourceSelectorVC.showErrorAlert(oneDriveError)
                }
            }
        }
    }
}

extension RemoteFilePickerCoordinator {
    private func startAddingOneDriveFile(token: OAuthToken) {
        let topVC = sourceSelectorVC
        OneDriveManager.shared.getDriveInfo(freshToken: token) { result in
            switch result {
            case .success(let driveInfo):
                self.oneDriveAccount = OneDriveAccount(
                    driveInfo: driveInfo,
                    token: token
                )
                if driveInfo.type == .personal {
                    self.showOneDriveFolder(folder: nil)
                } else {
                    self.performPremiumActionOrOfferUpgrade(
                        for: .canUseBusinessClouds,
                        allowBypass: true,
                        bypassTitle: LString.actionIgnoreAndContinue,
                        in: topVC
                    ) { [weak self] in
                        self?.showOneDriveFolder(folder: nil)
                    }
                }
            case .failure(let oneDriveError):
                topVC.showErrorAlert(oneDriveError)
            }
        }
    }
    
    private func showOneDriveFolder(folder: RemoteFileItem?) {
        guard let oneDriveAccount = oneDriveAccount else {
            Diag.warning("Not signed into any OneDrive account")
            assertionFailure()
            return
        }
        let folderName = folder?.fileInfo.fileName ?? oneDriveAccount.driveInfo.type.description
        OneDriveManager.shared.getItems(
            in: folder?.itemPath ?? "/",
            token: oneDriveAccount.token,
            tokenUpdater: nil 
        ) {
            [weak self] result in
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
                self.sourceSelectorVC.showErrorAlert(oneDriveError)
            }
        }
    }
    
    private func didSelectOneDriveFile(
        _ fileItem: RemoteFileItem,
        oneDriveAccount: OneDriveAccount
    ) {
        let fileURL = OneDriveFileURL.build(
            fileID: fileItem.itemID,
            filePath: fileItem.itemPath,
            driveInfo: oneDriveAccount.driveInfo
        )
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

        if item.isFolder {
            showOneDriveFolder(folder: item)
            return
        }
        performPremiumActionOrOfferUpgrade(for: .canUseBusinessClouds, in: viewController) {
            [weak self] in
            self?.didSelectOneDriveFile(item, oneDriveAccount: oneDriveAccount)
        }
    }
}
