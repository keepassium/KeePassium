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

class RemoteDataSourceSetupCoordinator<Manager: RemoteDataSourceManager>:
    BaseCoordinator,
    RemoteConnectionSetupAlertPresenting,
    RemoteFolderViewerDelegate
{
    let _manager: Manager
    let _stateIndicator: BusyStateIndicating
    let selectionMode: RemoteItemSelectionMode
    var _token: OAuthToken?
    var _accountInfo: Manager.AccountInfo?
    internal var _oldRef: URLReference?

    override var _presenterForModals: UIViewController {
        _router.navigationController
    }

    init(
        mode: RemoteItemSelectionMode,
        manager: Manager,
        oldRef: URLReference?,
        stateIndicator: BusyStateIndicating,
        router: NavigationRouter
    ) {
        self.selectionMode = mode
        self._manager = manager
        self._stateIndicator = stateIndicator
        self._oldRef = oldRef
        super.init(router: router)
    }

    override func start() {
        startSignIn()
    }

    func onAccountInfoAcquired(_ accountInfo: Manager.AccountInfo) {
        fatalError("Pure abstract method")
    }

    func showFolder(folder: Manager.ItemType, stateIndicator: BusyStateIndicating?) {
        guard let token = _token else {
            Diag.warning("Not signed into any \(Manager.self) account, cancelling")
            assertionFailure()
            return
        }

        let stateIndicator = stateIndicator ?? self._stateIndicator
        stateIndicator.indicateState(isBusy: true)
        _manager.getItems(
            in: folder,
            token: token,
            tokenUpdater: nil,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completionQueue: .main
        ) { [weak self, weak stateIndicator] result in
            guard let self else { return }
            stateIndicator?.indicateState(isBusy: false)
            switch result {
            case .success(let items):
                _showFolder(items: items, parent: folder, title: folder.name)
            case .failure(let remoteError):
                _presenterForModals.showErrorAlert(remoteError)
            }
        }
    }

    internal func _showFolder(
        items: [Manager.ItemType],
        parent: Manager.ItemType?,
        title: String
    ) {
        let vc = RemoteFolderViewerVC.make()
        vc.folder = parent
        vc.items = items
        vc.folderName = title
        vc.delegate = self
        vc.selectionMode = selectionMode
        if _initialViewController == nil {
            _pushInitialViewController(vc, animated: true)
        } else {
            _router.push(vc, animated: true, onPop: nil)
        }
    }

    private func startSignIn() {
        _initialViewController = nil
        _token = nil
        _accountInfo = nil

        _stateIndicator.indicateState(isBusy: true)
        let presenter = _router.navigationController
        let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        _manager.authenticate(presenter: presenter, timeout: timeout, completionQueue: .main) {
            [weak self] result in
            guard let self else { return }
            _stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let token):
                self._token = token
                onAuthorized(token: token)
            case .failure(let error):
                self._token = nil
                switch error {
                case .cancelledByUser:
                    break
                default:
                    _presenterForModals.showErrorAlert(error)
                }
            }
        }
    }

    private func onAuthorized(token: OAuthToken) {
        _stateIndicator.indicateState(isBusy: true)
        let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        _manager.getAccountInfo(freshToken: token, timeout: timeout, completionQueue: .main) {
            [weak self] result in
            guard let self else { return }
            _stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let accountInfo):
                onAccountInfoAcquired(accountInfo)
            case .failure(let error):
                _presenterForModals.showErrorAlert(error)
            }
        }
    }

    func selectItem(
        _ item: RemoteFileItem,
        in viewController: RemoteFolderViewerVC,
        completion: @escaping (URL, OAuthToken) -> Void
    ) {
        guard let token = _token else {
            Diag.warning("Not signed into any Dropbox account, cancelling")
            assertionFailure()
            return
        }
        guard let typedItem = item as? Manager.ItemType else {
            Diag.warning("Unexpected type of selected item")
            assertionFailure()
            return
        }

        if item.isFolder {
            showFolder(folder: typedItem, stateIndicator: viewController)
            return
        }

        let fileURL = typedItem.toURL()
        if typedItem.belongsToCorporateAccount {
            performPremiumActionOrOfferUpgrade(for: .canUseBusinessClouds, in: viewController) {
                completion(fileURL, token)
            }
        } else {
            completion(fileURL, token)
        }
    }

    func maybeSuggestPremium(isCorporateStorage: Bool, action: @escaping () -> Void) {
        let presenter = _presenterForModals
        if isCorporateStorage {
            performPremiumActionOrOfferUpgrade(
                for: .canUseBusinessClouds,
                allowBypass: true,
                bypassTitle: LString.actionIgnoreAndContinue,
                in: presenter
            ) {
                action()
            }
        } else {
            action()
        }
    }

    func didSelectItem(_ item: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        fatalError("Pure abstract method")
    }

    func didPressSave(to folder: RemoteFileItem, in viewController: RemoteFolderViewerVC) {
        fatalError("Pure abstract method")
    }

    func canSaveTo(folder: RemoteFileItem?, in viewController: RemoteFolderViewerVC) -> Bool {
        guard let folder else {
            return false
        }
        guard let itemTypeFolder = folder as? Manager.ItemType else {
            Diag.warning("Unexpected item type, ignoring")
            assertionFailure()
            return false
        }
        return itemTypeFolder.supportsItemCreation
    }
}
