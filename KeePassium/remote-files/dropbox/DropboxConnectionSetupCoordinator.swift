//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

protocol DropboxConnectionSetupCoordinatorDelegate: AnyObject {
    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: DropboxConnectionSetupCoordinator
    )
    func didPickRemoteFolder(
        _ folder: DropboxItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: DropboxConnectionSetupCoordinator
    )
}

final class DropboxConnectionSetupCoordinator: NSObject, RemoteDataSourceSetupCoordinator {
    typealias Manager = DropboxManager

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    let router: NavigationRouter

    let stateIndicator: BusyStateIndicating
    let selectionMode: RemoteItemSelectionMode
    let manager = DropboxManager.shared

    var token: OAuthToken?
    var accountInfo: DropboxAccountInfo?

    weak var firstVC: UIViewController?
    private var oldRef: URLReference?

    weak var delegate: DropboxConnectionSetupCoordinatorDelegate?

    init(
        router: NavigationRouter,
        stateIndicator: BusyStateIndicating,
        oldRef: URLReference?,
        selectionMode: RemoteItemSelectionMode = .file
    ) {
        self.router = router
        self.stateIndicator = stateIndicator
        self.oldRef = oldRef
        self.selectionMode = selectionMode
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        startSignIn()
    }

    func onAccountInfoAcquired(_ accountInfo: DropboxAccountInfo) {
        self.accountInfo = accountInfo
        if let oldRef,
           let url = oldRef.url,
           oldRef.fileProvider == .keepassiumDropbox
        {
            trySelectFile(url, onFailure: { [weak self] in
                guard let self else { return }
                self.oldRef = nil
                self.onAccountInfoAcquired(accountInfo)
            })
        }
        maybeSuggestPremium(isCorporateStorage: accountInfo.type.isCorporate) { [weak self] _ in
            guard let self else { return }
            self.showFolder(
                folder: DropboxItem.root(info: accountInfo),
                stateIndicator: self.stateIndicator
            )
        }
    }

    private func trySelectFile(_ fileURL: URL, onFailure: @escaping () -> Void) {
        guard let token,
              let item = DropboxItem.fromURL(fileURL)
        else {
            onFailure()
            return
        }
        manager.getItemInfo(
            item,
            token: token,
            tokenUpdater: nil,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        ) { [self, onFailure] result in
            switch result {
            case .success:
                Diag.info("Old file reference reinstated successfully")
                delegate?.didPickRemoteFile(url: fileURL, oauthToken: token, stateIndicator: stateIndicator, in: self)
            case .failure(let remoteError):
                Diag.debug("Failed to reinstate old file reference [message: \(remoteError.localizedDescription)]")
                onFailure()
            }
        }
    }
}

extension DropboxConnectionSetupCoordinator: RemoteFolderViewerDelegate {
    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        selectItem(item, in: viewController) { [weak self] fileURL, token in
            guard let self = self else {
                return
            }
            self.delegate?.didPickRemoteFile(url: fileURL, oauthToken: token, stateIndicator: stateIndicator, in: self)
            self.dismiss()
        }
    }

    func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let token else {
            Diag.warning("Not signed into any Dropbox account, cancelling")
            assertionFailure()
            return
        }
        guard let dropboxFolder = folder as? DropboxItem else {
            Diag.warning("Unexpected type of selected remote item")
            assertionFailure()
            return
        }
        guard dropboxFolder.isFolder else {
            Diag.warning("Selected item is not a folder")
            assertionFailure()
            return
        }
        delegate?.didPickRemoteFolder(
            dropboxFolder,
            oauthToken: token,
            stateIndicator: viewController,
            in: self
        )
    }
}
