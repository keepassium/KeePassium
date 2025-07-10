//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

#if MAIN_APP
extension DatabasePickerCoordinator {
    public func paywalledStartDatabaseCreator(presenter: UIViewController) {
        guard needsPremiumToAddDatabase() else {
            startDatabaseCreator(presenter: presenter)
            return
        }
        performPremiumActionOrOfferUpgrade(for: .canUseMultipleDatabases, in: presenter) {
            [weak self, weak presenter] in
            guard let self, let presenter else { return }
            startDatabaseCreator(presenter: presenter)
        }
    }

    public func startDatabaseCreator(presenter: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let databaseCreatorCoordinator = DatabaseCreatorCoordinator(router: modalRouter)
        databaseCreatorCoordinator.delegate = self
        databaseCreatorCoordinator.start()

        presenter.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(databaseCreatorCoordinator, onDismiss: nil)
    }
}

extension DatabasePickerCoordinator: DatabaseCreatorCoordinatorDelegate {
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference
    ) {
        selectDatabase(urlRef, animated: true)
    }
}
#endif
