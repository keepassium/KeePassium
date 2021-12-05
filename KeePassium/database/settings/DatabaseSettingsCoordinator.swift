//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSettingsCoordinatorDelegate: AnyObject {
    func didChangeDatabaseSettings(in coordinator: DatabaseSettingsCoordinator)
}

final class DatabaseSettingsCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabaseSettingsCoordinatorDelegate?

    private let router: NavigationRouter
    private let dbRef: URLReference
    private let dbSettingsVC: DatabaseSettingsVC
    
    init(fileRef: URLReference, router: NavigationRouter) {
        self.dbRef = fileRef
        self.router = router
        dbSettingsVC = DatabaseSettingsVC.instantiateFromStoryboard()
        dbSettingsVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(dbSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        let dsm = DatabaseSettingsManager.shared
        dbSettingsVC.isReadOnlyAccess = dsm.isReadOnly(dbRef)
    }
}

extension DatabaseSettingsCoordinator: DatabaseSettingsDelegate {
    func didPressClose(in viewController: DatabaseSettingsVC) {
        router.pop(viewController: dbSettingsVC, animated: true, completion: nil)
    }
    
    func canChangeReadOnly(in viewController: DatabaseSettingsVC) -> Bool {
        let isAlwaysReadOnly = dbRef.location == .internalBackup
        return !isAlwaysReadOnly
    }
    
    func didChangeSettings(isReadOnlyFile: Bool, in viewController: DatabaseSettingsVC) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isReadOnlyFile = isReadOnlyFile
        }
        delegate?.didChangeDatabaseSettings(in: self)
    }    
}