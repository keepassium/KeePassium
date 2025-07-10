//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    public func selectDatabase(_ fileRef: URLReference?, animated: Bool) {
        _selectedDatabase = fileRef
        selectFile(fileRef, animated: animated)
    }

    internal func _paywallDatabaseSelection(
        _ fileRef: URLReference,
        animated: Bool,
        in viewController: UIViewController,
        completion: @escaping ((URLReference) -> Void)
    ) {
        if fileRef == Settings.current.startupDatabase {
            completion(fileRef)
            return
        }

        let validSortedDatabases = enumerateDatabases(
            sorted: true,
            excludeBackup: true,
            excludeWithErrors: true
        )
        let isFirstDatabase = (fileRef === validSortedDatabases.first) || validSortedDatabases.isEmpty
        if isFirstDatabase || fileRef.location == .internalBackup {
            completion(fileRef)
        } else {
            performPremiumActionOrOfferUpgrade(
                for: .canUseMultipleDatabases,
                allowBypass: true,
                in: viewController,
                actionHandler: { [completion] in
                    completion(fileRef)
                }
            )
        }
    }
}
