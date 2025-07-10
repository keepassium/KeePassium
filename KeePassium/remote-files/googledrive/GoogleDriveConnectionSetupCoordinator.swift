//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

protocol GoogleDriveConnectionSetupCoordinatorDelegate: AnyObject {
    func didPickRemoteFile(
        url: URL,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: GoogleDriveConnectionSetupCoordinator
    )
    func didPickRemoteFolder(
        _ folder: GoogleDriveItem,
        oauthToken: OAuthToken,
        stateIndicator: BusyStateIndicating?,
        in coordinator: GoogleDriveConnectionSetupCoordinator
    )
}

final class GoogleDriveConnectionSetupCoordinator: RemoteDataSourceSetupCoordinator<GoogleDriveManager> {
    weak var delegate: GoogleDriveConnectionSetupCoordinatorDelegate?

    init(
        router: NavigationRouter,
        stateIndicator: BusyStateIndicating,
        oldRef: URLReference?,
        selectionMode: RemoteItemSelectionMode = .file
    ) {
        super.init(
            mode: selectionMode,
            manager: GoogleDriveManager.shared,
            oldRef: oldRef,
            stateIndicator: stateIndicator,
            router: router)
    }

    override func onAccountInfoAcquired(_ accountInfo: GoogleDriveAccountInfo) {
        self._accountInfo = accountInfo
        if let _oldRef,
           let url = _oldRef.url,
           _oldRef.fileProvider == .keepassiumGoogleDrive
        {
            trySelectFile(url, onFailure: { [weak self] in
                guard let self else { return }
                self._oldRef = nil
                self.onAccountInfoAcquired(accountInfo)
            })
        }
        maybeSuggestPremium(isCorporateStorage: accountInfo.isWorkspaceAccount) { [weak self] in
            self?._showFolder(
                items: [
                    GoogleDriveItem.getSpecialFolder(.myDrive, accountInfo: accountInfo),
                    GoogleDriveItem.getSpecialFolder(.sharedWithMe, accountInfo: accountInfo),
                ],
                parent: nil,
                title: accountInfo.serviceName
            )
        }
    }

    private func trySelectFile(_ fileURL: URL, onFailure: @escaping () -> Void) {
        guard let _token,
              let item = GoogleDriveItem.fromURL(fileURL)
        else {
            onFailure()
            return
        }
        let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        _manager.getItemInfo(item, token: _token, tokenUpdater: nil, timeout: timeout) {
            [self, onFailure] result in
            switch result {
            case .success:
                Diag.info("Old file reference reinstated successfully")
                delegate?.didPickRemoteFile(
                    url: fileURL,
                    oauthToken: _token,
                    stateIndicator: _stateIndicator,
                    in: self
                )
            case .failure(let remoteError):
                Diag.debug("Failed to reinstate old file reference [message: \(remoteError.localizedDescription)]")
                onFailure()
            }
        }
    }

    override func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let _token else {
            Diag.warning("Not signed into any Google account, cancelling")
            assertionFailure()
            return
        }
        guard let googleDriveItem = item as? GoogleDriveItem else {
            Diag.error("Unexpected type of selected item, cancelling")
            assertionFailure()
            return
        }

        guard !googleDriveItem.isShortcut else {
            Diag.debug("Shortcut item selected, requesting its info")
            _stateIndicator.indicateState(isBusy: true)
            let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
            _manager.getItemInfo(googleDriveItem, freshToken: _token, timeout: timeout, completionQueue: .main) {
                [weak self, weak viewController] result in
                guard let self, let viewController else { return }
                _stateIndicator.indicateState(isBusy: false)
                switch result {
                case .success(let resolvedItem):
                    Diag.debug("Shortcut item info updated successfully")
                    self.didSelectItem(resolvedItem, in: viewController)
                case .failure(let remoteError):
                    Diag.error("Failed to update shortcut info [message: \(remoteError.localizedDescription)]")
                    viewController.showErrorAlert(remoteError)
                }
            }
            return
        }

        selectItem(item, in: viewController) { [weak self] fileURL, token in
            guard let self else {
                return
            }
            self.delegate?.didPickRemoteFile(
                url: fileURL,
                oauthToken: token,
                stateIndicator: _stateIndicator,
                in: self)
            self.dismiss()
        }
    }

    override func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        guard let _token else {
            Diag.warning("Not signed into any Google account, cancelling")
            assertionFailure()
            return
        }
        guard let googleDriveFolder = folder as? GoogleDriveItem else {
            Diag.warning("Unexpected type of selected remote item")
            assertionFailure()
            return
        }
        guard !googleDriveFolder.isShortcut else {
            Diag.error("Cannot save to a shortcut folder")
            assertionFailure()
            return
        }
        guard googleDriveFolder.isFolder else {
            Diag.warning("Selected item is not a folder")
            assertionFailure()
            return
        }
        delegate?.didPickRemoteFolder(
            googleDriveFolder,
            oauthToken: _token,
            stateIndicator: viewController,
            in: self
        )
    }
}
