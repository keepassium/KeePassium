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
            case .oneDrive, .oneDriveForBusiness:
                startOneDriveSetup(connectionType: connectionType, stateIndicator: viewController)
            }
        }
    }
}

extension RemoteFileExportCoordinator: OneDriveConnectionSetupCoordinatorDelegate {
    private func startOneDriveSetup(connectionType: RemoteConnectionType, stateIndicator: BusyStateIndicating) {
        let setupCoordinator = OneDriveConnectionSetupCoordinator(
            connectionType: connectionType,
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
        Diag.debug("Will upload new file")
        stateIndicator?.indicateState(isBusy: true)
        OneDriveManager.shared.getItems(in: folder, token: oauthToken, tokenUpdater: nil) {
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
                    stateIndicator: stateIndicator,
                    presenter: coordinator.getModalPresenter()
                )
            case .failure(let oneDriveError):
                Diag.debug("Failed to get existing items [message: \(oneDriveError.localizedDescription)]")
                coordinator.getModalPresenter().showErrorAlert(oneDriveError)
            }
        }
    }

    private func checkExistenceAndCreate(
        fileName: String,
        in folder: OneDriveItem,
        existingItems: [OneDriveItem],
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        presenter: UIViewController
    ) {
        let doCreateFile = { [weak presenter] in
            stateIndicator?.indicateState(isBusy: true)
            OneDriveManager.shared.createFile(
                in: folder,
                contents: self.data,
                fileName: fileName,
                token: oauthToken,
                tokenUpdater: nil,
                completion: { [weak self, weak stateIndicator] result in
                    guard let self else { return }
                    stateIndicator?.indicateState(isBusy: false)
                    switch result {
                    case .success(let newFileItem):
                        Diag.debug("File created successfully")
                        let itemURL = newFileItem.toURL()
                        let credential = NetworkCredential(oauthToken: oauthToken)
                        self.delegate?.didFinishExport(to: itemURL, credential: credential, in: self)
                    case .failure(let oneDriveError):
                        Diag.debug("File creation failed [message: \(oneDriveError.localizedDescription)]")
                        presenter?.showErrorAlert(oneDriveError)
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
