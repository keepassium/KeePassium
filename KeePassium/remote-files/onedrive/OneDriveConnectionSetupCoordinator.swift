//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol OneDriveConnectionSetupCoordinatorDelegate: AnyObject {
    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: OneDriveConnectionSetupCoordinator
    )
    func didPickRemoteFolder(
        _ folder: OneDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: OneDriveConnectionSetupCoordinator
    )
}

final class OneDriveConnectionSetupCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: OneDriveConnectionSetupCoordinatorDelegate?

    private let router: NavigationRouter
    private let connectionType: RemoteConnectionType
    private let stateIndicator: BusyStateIndicating
    private let selectionMode: RemoteItemSelectionMode
    private var oldRef: URLReference?
    private weak var firstVC: UIViewController?

    private var token: OAuthToken?
    private var driveInfo: OneDriveDriveInfo?

    init(
        connectionType: RemoteConnectionType,
        stateIndicator: BusyStateIndicating,
        selectionMode: RemoteItemSelectionMode = .file,
        oldRef: URLReference?,
        router: NavigationRouter
    ) {
        self.connectionType = connectionType
        self.stateIndicator = stateIndicator
        self.selectionMode = selectionMode
        self.oldRef = oldRef
        self.router = router
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        firstVC = nil
        startSignIn()
    }

    func getModalPresenter() -> UIViewController {
        return router.navigationController
    }

    func showErrorAlert(_ error: OneDriveError) {
        getModalPresenter().showErrorAlert(error)
    }

    func dismiss() {
        if let firstVC {
            router.pop(viewController: firstVC, animated: true)
            self.firstVC = nil
        }
    }
}

extension OneDriveConnectionSetupCoordinator {
    private func startSignIn() {
        token = nil
        driveInfo = nil

        stateIndicator.indicateState(isBusy: true)
        let presenter = router.navigationController
        OneDriveManager.shared.authenticate(presenter: presenter) {
            [weak self] result in
            guard let self else { return }
            stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let token):
                self.token = token
                self.onAuthorized(token: token)
            case .failure(let oneDriveError):
                self.token = nil
                switch oneDriveError {
                case .cancelledByUser:
                    break
                default:
                    self.showErrorAlert(oneDriveError)
                }
            }
        }
    }

    private func onAuthorized(token: OAuthToken) {
        stateIndicator.indicateState(isBusy: true)
        OneDriveManager.shared.getDriveInfo(parent: nil, freshToken: token) { [weak self] result in
            guard let self else { return }
            self.stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let driveInfo):
                onDriveInfoAcquired(driveInfo)
            case .failure(let oneDriveError):
                router.navigationController.showErrorAlert(oneDriveError)
            }
        }
    }

    private func onDriveInfoAcquired(_ driveInfo: OneDriveDriveInfo) {
        self.driveInfo = driveInfo
        if let oldRef,
           let url = oldRef.url,
           oldRef.fileProvider == .keepassiumOneDrive
        {
            trySelectFile(url, onFailure: { [weak self] in
                guard let self else { return }
                self.oldRef = nil
                self.onDriveInfoAcquired(driveInfo)
            })
            return
        }

        if driveInfo.type.isCorporate {
            let presenter = router.navigationController
            performPremiumActionOrOfferUpgrade(
                for: .canUseBusinessClouds,
                allowBypass: true,
                bypassTitle: LString.actionIgnoreAndContinue,
                in: presenter
            ) { [weak self] in
                guard let self else { return }
                self.showWelcomeFolder()
            }
        } else {
            showWelcomeFolder()
        }
    }

    private func trySelectFile(_ fileURL: URL, onFailure: @escaping () -> Void) {
        guard let token,
              let oneDriveItem = OneDriveItem.fromURL(fileURL)
        else {
            onFailure()
            return
        }
        OneDriveManager.shared.getItemInfo(
            oneDriveItem,
            token: token,
            tokenUpdater: nil
        ) { [self, onFailure] result in
            switch result {
            case .success(let oneDriveItem):
                Diag.info("Old file reference reinstated successfully")
                didSelectFile(oneDriveItem, stateIndicator: stateIndicator)
            case .failure(let oneDriveError):
                Diag.debug("Failed to reinstate old file reference [message: \(oneDriveError.localizedDescription)]")
                onFailure()
            }
        }
    }

    private func showWelcomeFolder() {
        guard let driveInfo else {
            Diag.warning("Not signed into any OneDrive account, cancelling")
            assertionFailure()
            return
        }
        let vc = RemoteFolderViewerVC.make()
        vc.items = [
            OneDriveItem.getPersonalFilesFolder(driveInfo: driveInfo),
            OneDriveItem.getSharedWithMeFolder(driveInfo: driveInfo),
        ]
        vc.folder = nil
        vc.folderName = driveInfo.type.description
        vc.delegate = self
        vc.selectionMode = selectionMode
        router.push(vc, animated: true, onPop: {})

        if firstVC == nil {
            firstVC = vc
        }
    }

    private func showFolder(folder: OneDriveItem, presenter: UIViewController) {
        guard let token else {
            Diag.warning("Not signed into any OneDrive account, cancelling")
            assertionFailure()
            return
        }

        stateIndicator.indicateState(isBusy: true)
        OneDriveManager.shared.getItems(
            in: folder,
            token: token,
            tokenUpdater: nil
        ) { [weak self, weak presenter] result in
            guard let self, let presenter else { return }
            self.stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let items):
                let vc = RemoteFolderViewerVC.make()
                vc.folder = folder
                vc.items = items
                vc.folderName = folder.name
                vc.delegate = self
                vc.selectionMode = selectionMode
                self.router.push(vc, animated: true, onPop: nil)
            case .failure(let oneDriveError):
                presenter.showErrorAlert(oneDriveError)
            }
        }
    }
}

extension OneDriveConnectionSetupCoordinator: RemoteFolderViewerDelegate {
    func canSaveTo(folder: RemoteFileItem?, in viewController: RemoteFolderViewerVC) -> Bool {
        guard let folder else {
            return false
        }
        guard let oneDriveFolder = folder as? OneDriveItem else {
            Diag.warning("Unexpected item type, ignoring")
            assertionFailure()
            return false
        }
        return oneDriveFolder.supportsItemCreation
    }

    func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let token else {
            Diag.warning("Not signed into any OneDrive account, cancelling")
            assertionFailure()
            return
        }
        guard let oneDriveFolder = folder as? OneDriveItem else {
            Diag.warning("Unexpected type of selected remote item")
            assertionFailure()
            return
        }
        guard oneDriveFolder.isFolder else {
            Diag.warning("Selected item is not a folder")
            assertionFailure()
            return
        }
        delegate?.didPickRemoteFolder(
            oneDriveFolder,
            oauthToken: token,
            stateIndicator: viewController,
            in: self
        )
    }

    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let token else {
            Diag.warning("Not signed into any OneDrive account, cancelling")
            assertionFailure()
            return
        }
        guard let oneDriveItem = item as? OneDriveItem else {
            Diag.warning("Unexpected type of selected item")
            assertionFailure()
            return
        }

        if item.isFolder {
            showFolder(folder: oneDriveItem, presenter: viewController)
            return
        }

        stateIndicator.indicateState(isBusy: true)
        OneDriveManager.shared.updateItemInfo(
            oneDriveItem,
            freshToken: token,
            completionQueue: .main,
            completion: { [weak self, weak viewController] result in
                guard let self, let viewController  else { return }
                viewController.indicateState(isBusy: false)
                switch result {
                case .success(let fileItem):
                    self.onSelectedFileInfoUpdated(fileItem, in: viewController)
                case .failure(let oneDriveError):
                    Diag.info("Failed to update shared item [message: \(oneDriveError.localizedDescription)]")
                    viewController.showErrorAlert(oneDriveError)
                }
            }
        )
    }

    private func onSelectedFileInfoUpdated(
        _ fileItem: OneDriveItem,
        in viewController: RemoteFolderViewerVC
    ) {
        if fileItem.driveInfo.type.isCorporate {
            performPremiumActionOrOfferUpgrade(for: .canUseBusinessClouds, in: viewController) { [weak self] in
                self?.didSelectFile(fileItem, stateIndicator: viewController)
            }
        } else {
            didSelectFile(fileItem, stateIndicator: viewController)
        }
    }

    private func didSelectFile(_ fileItem: OneDriveItem, stateIndicator: BusyStateIndicating?) {
        guard let token else {
            Diag.error("Not signed into any OneDrive account, cancelling")
            assertionFailure()
            return
        }
        let fileURL = fileItem.toURL()
        delegate?.didPickRemoteFile(url: fileURL, oauthToken: token, stateIndicator: stateIndicator, in: self)
        dismiss()
    }
}
