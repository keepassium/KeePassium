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

protocol RemoteDataSourceSetupCoordinator<Manager>: Coordinator, RemoteFolderViewerDelegate {
    associatedtype Manager: RemoteDataSourceManager

    var router: NavigationRouter { get }
    var firstVC: UIViewController? { get set }
    var manager: Manager { get }
    var stateIndicator: BusyStateIndicating { get }
    var selectionMode: RemoteItemSelectionMode { get }
    var token: OAuthToken? { get set }
    var accountInfo: Manager.AccountInfo? { get set }

    func getModalPresenter() -> UIViewController
    func showErrorAlert(_ error: RemoteError)
    func onAccountInfoAcquired(_ accountInfo: Manager.AccountInfo)
}

extension RemoteDataSourceSetupCoordinator {
    func getModalPresenter() -> UIViewController {
        return router.navigationController
    }

    func showErrorAlert(_ error: RemoteError) {
        getModalPresenter().showErrorAlert(error)
    }

    func dismiss() {
        guard let firstVC else {
            return
        }

        router.pop(viewController: firstVC, animated: true)
        self.firstVC = nil
    }

    func showFolder(folder: Manager.ItemType, stateIndicator: BusyStateIndicating?) {
        guard let token else {
            Diag.warning("Not signed into any \(Manager.self) account, cancelling")
            assertionFailure()
            return
        }

        let stateIndicator = stateIndicator ?? self.stateIndicator
        stateIndicator.indicateState(isBusy: true)
        manager.getItems(
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
                showFolder(items: items, parent: folder, title: folder.name)
            case .failure(let remoteError):
                showErrorAlert(remoteError)
            }
        }
    }

    func showFolder(
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
        if self.firstVC == nil {
            self.firstVC = vc
        }
        router.push(vc, animated: true, onPop: nil)
    }

    func startSignIn() {
        firstVC = nil
        token = nil
        accountInfo = nil

        stateIndicator.indicateState(isBusy: true)
        let presenter = router.navigationController
        let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        manager.authenticate(presenter: presenter, timeout: timeout, completionQueue: .main) {
            [weak self] result in
            guard let self else { return }
            stateIndicator.indicateState(isBusy: false)
            switch result {
            case .success(let token):
                self.token = token
                self.onAuthorized(token: token)
            case .failure(let error):
                self.token = nil
                switch error {
                case .cancelledByUser:
                    break
                default:
                    self.showErrorAlert(error)
                }
            }
        }
    }

    func onAuthorized(token: OAuthToken) {
        stateIndicator.indicateState(isBusy: true)
        let timeout = Timeout(duration: FileDataProvider.defaultTimeoutDuration)
        manager.getAccountInfo(freshToken: token, timeout: timeout, completionQueue: .main) { [weak self] result in
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

    func selectItem(
        _ item: RemoteFileItem,
        in viewController: RemoteFolderViewerVC,
        completion: @escaping (URL, OAuthToken) -> Void
    ) {
        guard let token else {
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

    func maybeSuggestPremium(isCorporateStorage: Bool, action: @escaping (RouterNavigationController) -> Void) {
        let presenter = router.navigationController

        if isCorporateStorage {
            performPremiumActionOrOfferUpgrade(
                for: .canUseBusinessClouds,
                allowBypass: true,
                bypassTitle: LString.actionIgnoreAndContinue,
                in: presenter
            ) {
                action(presenter)
            }
        } else {
            action(presenter)
        }
    }
}
