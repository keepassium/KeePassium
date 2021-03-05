//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol DatabaseManagerObserver: class {
    func databaseManager(database urlRef: URLReference, isCancelled: Bool)
    
    func databaseManager(progressDidChange progress: ProgressEx)
    
    func databaseManager(willLoadDatabase urlRef: URLReference)
    func databaseManager(didLoadDatabase urlRef: URLReference, warnings: DatabaseLoadingWarnings)
    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?)
    func databaseManager(database urlRef: URLReference, invalidMasterKey message: String)
    
    func databaseManager(willSaveDatabase urlRef: URLReference)
    func databaseManager(didSaveDatabase urlRef: URLReference)
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?)

    func databaseManager(willCreateDatabase urlRef: URLReference)

    func databaseManager(willCloseDatabase urlRef: URLReference)
    func databaseManager(didCloseDatabase urlRef: URLReference)
}

public extension DatabaseManagerObserver {
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {}
    func databaseManager(progressDidChange progress: ProgressEx) {}
    func databaseManager(willLoadDatabase urlRef: URLReference) {}
    func databaseManager(didLoadDatabase urlRef: URLReference, warnings: DatabaseLoadingWarnings) {}
    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?) {}
    func databaseManager(database urlRef: URLReference, invalidMasterKey message: String) {}
    func databaseManager(willSaveDatabase urlRef: URLReference) {}
    func databaseManager(didSaveDatabase urlRef: URLReference) {}
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?) {}
    func databaseManager(willCreateDatabase urlRef: URLReference) {}
    func databaseManager(willCloseDatabase urlRef: URLReference) {}
    func databaseManager(didCloseDatabase urlRef: URLReference) {}
}

