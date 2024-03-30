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
    private var accountInfo: DropboxAccountInfo?

    weak var firstVC: UIViewController?

    weak var delegate: DropboxConnectionSetupCoordinatorDelegate?

    init(
        router: NavigationRouter,
        stateIndicator: BusyStateIndicating,
        selectionMode: RemoteItemSelectionMode = .file
    ) {
        self.router = router
        self.stateIndicator = stateIndicator
        self.selectionMode = selectionMode
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        accountInfo = nil
        startSignIn()
    }

    func onAuthorized(token: OAuthToken) {
        stateIndicator.indicateState(isBusy: true)
        manager.getAccountInfo(freshToken: token) { [weak self] result in
            guard let self else { return }
            self.stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let accountInfo):
                onAccountInfoAcquired(accountInfo)
            case .failure(let error):
                router.navigationController.showErrorAlert(error)
            }
        }
    }

    private func onAccountInfoAcquired(_ accountInfo: DropboxAccountInfo) {
        self.accountInfo = accountInfo
        maybeSuggestPremium(isCorporateStorage: accountInfo.type.isCorporate) { [weak self] presenter in
            self?.showFolder(folder: DropboxItem.root(info: accountInfo), presenter: presenter)
        }
    }
}

extension DropboxConnectionSetupCoordinator: RemoteFolderViewerDelegate {
    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let token else {
            Diag.warning("Not signed into any Dropbox account, cancelling")
            assertionFailure()
            return
        }
        guard let dropboxItem = item as? DropboxItem else {
            Diag.warning("Unexpected type of selected item")
            assertionFailure()
            return
        }

        if item.isFolder {
            showFolder(folder: dropboxItem, presenter: viewController)
            return
        }

        let handleSelection = { [weak self] in
            guard let self = self else {
                return
            }
            let fileURL = dropboxItem.toURL()
            self.delegate?.didPickRemoteFile(url: fileURL, oauthToken: token, stateIndicator: stateIndicator, in: self)
            self.dismiss()
        }

        if dropboxItem.info.type.isCorporate {
            performPremiumActionOrOfferUpgrade(for: .canUseBusinessClouds, in: viewController) {
                handleSelection()
            }
        } else {
            handleSelection()
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
