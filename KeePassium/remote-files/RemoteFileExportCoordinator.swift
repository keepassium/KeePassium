//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol RemoteFileExportCoordinatorDelegate: AnyObject {
    func didFinishExport(
        to remoteURL: URL,
        credential: NetworkCredential,
        in coordinator: RemoteFileExportCoordinator
    )
}

final class RemoteFileExportCoordinator: BaseCoordinator {
    weak var delegate: RemoteFileExportCoordinatorDelegate?

    private let data: ByteArray
    private let fileName: String
    private let connectionTypePicker: ConnectionTypePickerVC

    init(data: ByteArray, fileName: String, router: NavigationRouter) {
        self.data = data
        self.fileName = fileName
        connectionTypePicker = ConnectionTypePickerVC.make()
        super.init(router: router)
        connectionTypePicker.delegate = self
        connectionTypePicker.showsOtherLocations = false
    }

    override func start() {
        super.start()
        _pushInitialViewController(connectionTypePicker, animated: true)
    }

    private func upload<Manager: RemoteDataSourceManager> (
        _ folder: Manager.ItemType,
        oauthToken: OAuthToken,
        timeout: Timeout,
        manager: Manager,
        stateIndicator: BusyStateIndicating?,
        alertPresenter: RemoteConnectionSetupAlertPresenting
    ) {
        Diag.debug("Will upload new file")
        stateIndicator?.indicateState(isBusy: true)
        manager.getItems(in: folder, token: oauthToken, tokenUpdater: nil, timeout: timeout, completionQueue: .main) {
            [weak self, weak alertPresenter, weak stateIndicator] result in
            guard let self, let alertPresenter else { return }
            stateIndicator?.indicateState(isBusy: false)
            switch result {
            case .success(let existingItems):
                checkExistenceAndCreate(
                    fileName: self.fileName,
                    in: folder,
                    existingItems: existingItems,
                    oauthToken: oauthToken,
                    timeout: timeout,
                    manager: manager,
                    stateIndicator: stateIndicator,
                    alertPresenter: alertPresenter
                )
            case .failure(let error):
                Diag.debug("Failed to get existing items [message: \(error.localizedDescription)]")
                alertPresenter.showErrorAlert(error)
            }
        }
    }

    private func upload(
        folder: WebDAVItem,
        credential: NetworkCredential,
        timeout: Timeout,
        stateIndicator: BusyStateIndicating?,
        alertPresenter: RemoteConnectionSetupAlertPresenting
    ) {
        Diag.debug("Will upload new file to WebDAV")
        stateIndicator?.indicateState(isBusy: true)

        let webDAVManager = WebDAVManager.shared
        webDAVManager.getItems(
            in: folder,
            credential: credential,
            timeout: timeout,
            completionQueue: .main
        ) { [weak self, weak stateIndicator, weak alertPresenter] result in
            guard let self, let alertPresenter else { return }
            stateIndicator?.indicateState(isBusy: false)

            switch result {
            case .success(let existingItems):
                self.handleExistingWebDAVItemsAndUpload(
                    existingItems: existingItems,
                    in: folder,
                    credential: credential,
                    timeout: timeout,
                    webDAVManager: webDAVManager,
                    stateIndicator: stateIndicator,
                    alertPresenter: alertPresenter
                )
            case .failure(let error):
                Diag.debug("Failed to get WebDAV folder contents [message: \(error.localizedDescription)]")
                alertPresenter.showErrorAlert(error)
            }
        }
    }

    private func handleExistingWebDAVItemsAndUpload(
        existingItems: [WebDAVItem],
        in folder: WebDAVItem,
        credential: NetworkCredential,
        timeout: Timeout,
        webDAVManager: WebDAVManager,
        stateIndicator: BusyStateIndicating?,
        alertPresenter: RemoteConnectionSetupAlertPresenting
    ) {
        let fileAlreadyExists = existingItems.contains { !$0.isFolder && $0.name == self.fileName }
        if !fileAlreadyExists {
            performWebDAVUpload(
                to: folder,
                credential: credential,
                timeout: timeout,
                webDAVManager: webDAVManager,
                stateIndicator: stateIndicator,
                alertPresenter: alertPresenter
            )
            return
        }

        alertPresenter.showOverwriteConfirmation(fileName: fileName, onConfirm: {
            [weak self, weak stateIndicator, weak alertPresenter] _ in
            guard let self, let alertPresenter else { return }
            performWebDAVUpload(
                to: folder,
                credential: credential,
                timeout: timeout,
                webDAVManager: webDAVManager,
                stateIndicator: stateIndicator,
                alertPresenter: alertPresenter
            )
        })
    }

    private func performWebDAVUpload(
        to folder: WebDAVItem,
        credential: NetworkCredential,
        timeout: Timeout,
        webDAVManager: WebDAVManager,
        stateIndicator: BusyStateIndicating?,
        alertPresenter: RemoteConnectionSetupAlertPresenting
    ) {
        stateIndicator?.indicateState(isBusy: true)
        let url = folder.url.appendingPathComponent(self.fileName)

        webDAVManager.uploadFile(
            data: self.data,
            url: url,
            credential: credential,
            timeout: timeout,
            completionQueue: .main
        ) { [weak self, weak stateIndicator, weak alertPresenter] result in
            guard let self, let alertPresenter else { return }
            stateIndicator?.indicateState(isBusy: false)
            switch result {
            case .success:
                Diag.debug("File created successfully on WebDAV")
                self.delegate?.didFinishExport(
                    to: WebDAVFileURL.build(nakedURL: url),
                    credential: credential,
                    in: self
                )
            case .failure(let error):
                Diag.debug("Failed to get WebDAV folder contents [message: \(error.localizedDescription)]")
                alertPresenter.showErrorAlert(error)
            }
        }
    }

    private func checkExistenceAndCreate<ItemType: RemoteFileItem>(
        fileName: String,
        in folder: ItemType,
        existingItems: [ItemType],
        oauthToken: OAuthToken,
        timeout: Timeout,
        manager: some RemoteDataSourceManager<ItemType>,
        stateIndicator: BusyStateIndicating?,
        alertPresenter: RemoteConnectionSetupAlertPresenting
    ) {
        let doCreateFile = { [weak alertPresenter] in
            stateIndicator?.indicateState(isBusy: true)
            manager.createFile(
                in: folder,
                contents: self.data,
                fileName: fileName,
                token: oauthToken,
                tokenUpdater: nil,
                timeout: timeout,
                completion: { [weak self, weak stateIndicator] result in
                    guard let self else { return }
                    stateIndicator?.indicateState(isBusy: false)
                    switch result {
                    case .success(let newFileItem):
                        Diag.debug("File created successfully")
                        let itemURL = newFileItem.toURL()
                        let credential = NetworkCredential(oauthToken: oauthToken)
                        self.delegate?.didFinishExport(to: itemURL, credential: credential, in: self)
                    case .failure(let error):
                        Diag.debug("File creation failed [message: \(error.localizedDescription)]")
                        alertPresenter?.showErrorAlert(error)
                    }
                }
            )
        }

        let fileAlreadyExists = existingItems.contains(where: {
            !$0.isFolder && $0.name == self.fileName
        })
        if !fileAlreadyExists {
            doCreateFile()
            return
        }

        alertPresenter.showOverwriteConfirmation(fileName: fileName, onConfirm: { _ in
            doCreateFile()
        })
    }
}

extension RemoteFileExportCoordinator: ConnectionTypePickerDelegate {
    func isConnectionTypeEnabled(
        _ connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) -> Bool {
        return true
    }

    func willSelect(
        connectionType: KeePassiumLib.RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) -> Bool {
        if connectionType.isPremiumUpgradeRequired {
            offerPremiumUpgrade(for: .canUseBusinessClouds, in: viewController)
            return false
        }
        return true
    }

    func didSelect(
        connectionType: KeePassiumLib.RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) {
        viewController.ensuringNetworkAccessPermitted { [weak self] in
            guard let self else { return }
            switch connectionType {
            case .webdav:
                startWebDAVSetup(stateIndicator: viewController)
            case .oneDrivePersonal, .oneDriveForBusiness:
                startOneDriveSetup(stateIndicator: viewController)
            case .dropbox, .dropboxBusiness:
                startDropboxSetup(stateIndicator: viewController)
            case .googleDrive, .googleWorkspace:
                startGoogleDriveSetup(stateIndicator: viewController)
            }
        }
    }

    func didSelectOtherLocations(in viewController: ConnectionTypePickerVC) {
        assertionFailure("Not implemented, this option is supposed to be hidden")
    }
}

extension RemoteFileExportCoordinator: GoogleDriveConnectionSetupCoordinatorDelegate {
    private func startGoogleDriveSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = GoogleDriveConnectionSetupCoordinator(
            router: _router,
            stateIndicator: stateIndicator,
            oldRef: nil,
            selectionMode: .folder
        )
        setupCoordinator.delegate = self
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator, onDismiss: nil)
    }

    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: GoogleDriveConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteFolder instead")
    }

    func didPickRemoteFolder(
        _ folder: GoogleDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: GoogleDriveConnectionSetupCoordinator)
    {
        upload(
            folder,
            oauthToken: oauthToken,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            manager: GoogleDriveManager.shared,
            stateIndicator: stateIndicator,
            alertPresenter: coordinator
        )
    }
}

extension RemoteFileExportCoordinator: DropboxConnectionSetupCoordinatorDelegate {
    private func startDropboxSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = DropboxConnectionSetupCoordinator(
            router: _router,
            stateIndicator: stateIndicator,
            oldRef: nil,
            selectionMode: .folder
        )
        setupCoordinator.delegate = self
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator, onDismiss: nil)
    }

    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: DropboxConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteFolder instead")
    }

    func didPickRemoteFolder(
        _ folder: DropboxItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: DropboxConnectionSetupCoordinator)
    {
        upload(
            folder,
            oauthToken: oauthToken,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            manager: DropboxManager.shared,
            stateIndicator: stateIndicator,
            alertPresenter: coordinator
        )
    }
}

extension RemoteFileExportCoordinator: OneDriveConnectionSetupCoordinatorDelegate {
    private func startOneDriveSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = OneDriveConnectionSetupCoordinator(
            stateIndicator: stateIndicator,
            selectionMode: .folder,
            oldRef: nil,
            router: _router
        )
        setupCoordinator.delegate = self
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator, onDismiss: nil)
    }

    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: OneDriveConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteFolder instead")
    }

    func didPickRemoteFolder(
        _ folder: OneDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: OneDriveConnectionSetupCoordinator
    ) {
        upload(
            folder,
            oauthToken: oauthToken,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            manager: OneDriveManager.shared,
            stateIndicator: stateIndicator,
            alertPresenter: coordinator
        )
    }
}

extension RemoteFileExportCoordinator: WebDAVConnectionSetupCoordinatorDelegate {
    private func startWebDAVSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = WebDAVConnectionSetupCoordinator(
            router: _router,
            selectionMode: .folder
        )
        setupCoordinator.delegate = self
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator, onDismiss: nil)
    }

    func didPickRemoteFile(
        url: URL,
        credential: NetworkCredential,
        in coordinator: WebDAVConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteFolder instead")
    }

    func didPickRemoteFolder(
        _ folder: WebDAVItem,
        credential: NetworkCredential,
        stateIndicator: BusyStateIndicating?,
        in coordinator: WebDAVConnectionSetupCoordinator
    ) {
        upload(
            folder: folder,
            credential: credential,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            stateIndicator: stateIndicator,
            alertPresenter: coordinator
        )
    }
}
