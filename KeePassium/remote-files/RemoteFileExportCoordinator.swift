//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol RemoteFileExportCoordinatorDelegate: AnyObject {
    func didCancelExport(in coordinator: RemoteFileExportCoordinator)
    func didFinishExport(
        to remoteURL: URL,
        credential: NetworkCredential,
        in coordinator: RemoteFileExportCoordinator
    )
}

final class RemoteFileExportCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: RemoteFileExportCoordinatorDelegate?

    private let router: NavigationRouter
    private let data: ByteArray
    private let fileName: String
    private let connectionTypePicker: ConnectionTypePickerVC

    init(data: ByteArray, fileName: String, router: NavigationRouter) {
        self.data = data
        self.fileName = fileName
        self.router = router
        connectionTypePicker = ConnectionTypePickerVC.make()
        connectionTypePicker.delegate = self
        connectionTypePicker.showsOtherLocations = false
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(connectionTypePicker, animated: true, onPop: { [weak self] in
            guard let self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    private func upload<Coordinator: RemoteDataSourceSetupCoordinator>(
        _ folder: Coordinator.Manager.ItemType,
        oauthToken: OAuthToken,
        timeout: Timeout,
        manager: Coordinator.Manager,
        stateIndicator: BusyStateIndicating?,
        coordinator: Coordinator
    ) {
        Diag.debug("Will upload new file")
        stateIndicator?.indicateState(isBusy: true)
        manager.getItems(in: folder, token: oauthToken, tokenUpdater: nil, timeout: timeout, completionQueue: .main) {
            [weak self, weak coordinator, weak stateIndicator] result in
            guard let self, let coordinator else { return }
            stateIndicator?.indicateState(isBusy: false)
            switch result {
            case .success(let existingItems):
                checkExistenceAndCreate(
                    fileName: self.fileName,
                    in: folder,
                    existingItems: existingItems,
                    oauthToken: oauthToken,
                    timeout: timeout,
                    stateIndicator: stateIndicator,
                    manager: manager,
                    presenter: coordinator.getModalPresenter()
                )
            case .failure(let error):
                Diag.debug("Failed to get existing items [message: \(error.localizedDescription)]")
                coordinator.getModalPresenter().showErrorAlert(error)
            }
        }
    }

    private func checkExistenceAndCreate<ItemType: RemoteFileItem>(
        fileName: String,
        in folder: ItemType,
        existingItems: [ItemType],
        oauthToken: OAuthToken,
        timeout: Timeout,
        stateIndicator: BusyStateIndicating?,
        manager: some RemoteDataSourceManager<ItemType>,
        presenter: UIViewController
    ) {
        let doCreateFile = { [weak presenter] in
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
                        presenter?.showErrorAlert(error)
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

        let overwriteAlert = UIAlertController(
            title: LString.fileAlreadyExists,
            message: fileName,
            preferredStyle: .alert)
        overwriteAlert.addAction(title: LString.actionOverwrite, style: .destructive) { _ in
            doCreateFile()
        }
        overwriteAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        presenter.present(overwriteAlert, animated: true)
    }
}

extension RemoteFileExportCoordinator: ConnectionTypePickerDelegate {
    func isConnectionTypeEnabled(
        _ connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) -> Bool {
        return connectionType != .webdav
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
                assertionFailure("Not implemented yet")
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
            router: router,
            stateIndicator: stateIndicator,
            oldRef: nil,
            selectionMode: .folder
        )
        setupCoordinator.delegate = self
        setupCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator)
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
            coordinator: coordinator
        )
    }
}

extension RemoteFileExportCoordinator: DropboxConnectionSetupCoordinatorDelegate {
    private func startDropboxSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = DropboxConnectionSetupCoordinator(
            router: router,
            stateIndicator: stateIndicator,
            oldRef: nil,
            selectionMode: .folder
        )
        setupCoordinator.delegate = self
        setupCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator)
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
            coordinator: coordinator
        )
    }
}

extension RemoteFileExportCoordinator: OneDriveConnectionSetupCoordinatorDelegate {
    private func startOneDriveSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = OneDriveConnectionSetupCoordinator(
            stateIndicator: stateIndicator,
            selectionMode: .folder,
            oldRef: nil,
            router: router
        )
        setupCoordinator.delegate = self
        setupCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        setupCoordinator.start()
        addChildCoordinator(setupCoordinator)
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
            coordinator: coordinator
        )
    }
}
