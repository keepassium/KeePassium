//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
    func didSelectSystemFilePicker(
        in coordinator: RemoteFilePickerCoordinator
    )
}

final class RemoteFilePickerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: RemoteFilePickerCoordinatorDelegate?

    private let router: NavigationRouter
    private let connectionTypePicker: ConnectionTypePickerVC
    private var oldRef: URLReference?

    init(oldRef: URLReference?, router: NavigationRouter) {
        self.router = router
        self.oldRef = oldRef
        connectionTypePicker = ConnectionTypePickerVC.make()
        connectionTypePicker.delegate = self
        connectionTypePicker.showsOtherLocations = true
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        setupDismissButton()
        startObservingPremiumStatus(#selector(premiumStatusDidChange))

        let connectionType: RemoteConnectionType?
        switch oldRef?.fileProvider {
        case .some(.keepassiumWebDAV):
            connectionType = .webdav
        case .some(.keepassiumDropbox):
            connectionType = .dropbox
        case .some(.keepassiumGoogleDrive):
            connectionType = .googleDrive
        case .some(.keepassiumOneDrivePersonal):
            connectionType = .oneDrivePersonal
        case .some(.keepassiumOneDriveBusiness):
            connectionType = .oneDriveForBusiness
        default:
            connectionType = nil
        }

        let animated = (connectionType == nil) 
        router.push(connectionTypePicker, animated: animated, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        if let connectionType {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                didSelect(connectionType: connectionType, in: connectionTypePicker)
            }
        }
    }

    private func setupDismissButton() {
        guard router.navigationController.topViewController == nil else {
            return
        }

        let cancelButton = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss()
            },
            menu: nil)
        connectionTypePicker.navigationItem.leftBarButtonItem = cancelButton
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        router.pop(viewController: connectionTypePicker, animated: true, completion: completion)
    }

    @objc
    private func premiumStatusDidChange() {
        connectionTypePicker.refresh()
    }
}

extension RemoteFilePickerCoordinator: ConnectionTypePickerDelegate {
    func isConnectionTypeEnabled(
        _ connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC
    ) -> Bool {
        return true
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

    func didSelectOtherLocations(in viewController: ConnectionTypePickerVC) {
        dismiss { [self] in
            delegate?.didSelectSystemFilePicker(in: self)
        }
    }
}

extension RemoteFilePickerCoordinator: WebDAVConnectionSetupCoordinatorDelegate {
    private func startWebDAVSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = WebDAVConnectionSetupCoordinator(
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
        credential: NetworkCredential,
        in coordinator: WebDAVConnectionSetupCoordinator
    ) {
        delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
        dismiss()
    }
}

extension RemoteFilePickerCoordinator: GoogleDriveConnectionSetupCoordinatorDelegate {
    private func startGoogleDriveSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = GoogleDriveConnectionSetupCoordinator(
            router: router,
            stateIndicator: stateIndicator,
            oldRef: oldRef
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
        let credential = NetworkCredential(oauthToken: oauthToken)
        delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
        dismiss()
    }

    func didPickRemoteFolder(
        _ folder: GoogleDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: GoogleDriveConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteItem instead")
    }
}

extension RemoteFilePickerCoordinator: DropboxConnectionSetupCoordinatorDelegate {
    private func startDropboxSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = DropboxConnectionSetupCoordinator(
            router: router,
            stateIndicator: stateIndicator,
            oldRef: oldRef
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
        let credential = NetworkCredential(oauthToken: oauthToken)
        delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
        dismiss()
    }

    func didPickRemoteFolder(
        _ folder: DropboxItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: DropboxConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteItem instead")
    }
}

extension RemoteFilePickerCoordinator: OneDriveConnectionSetupCoordinatorDelegate {
    private func startOneDriveSetup(stateIndicator: BusyStateIndicating) {
        let setupCoordinator = OneDriveConnectionSetupCoordinator(
            stateIndicator: stateIndicator,
            oldRef: oldRef,
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
        let credential = NetworkCredential(oauthToken: oauthToken)
        delegate?.didPickRemoteFile(url: url, credential: credential, in: self)
        dismiss()
    }

    func didPickRemoteFolder(
        _ folder: OneDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: OneDriveConnectionSetupCoordinator
    ) {
        assertionFailure("Expected didPickRemoteItem instead")
    }
}
