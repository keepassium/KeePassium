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
    func databaseManager(database urlRef: URLReference, savingError message: String, reason: String?)

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
    func databaseManager(database urlRef: URLReference, savingError message: String, reason: String?) {}
    func databaseManager(willCreateDatabase urlRef: URLReference) {}
    func databaseManager(willCloseDatabase urlRef: URLReference) {}
    func databaseManager(didCloseDatabase urlRef: URLReference) {}
}

public class DatabaseManagerNotifications {
    private weak var observer: DatabaseManagerObserver?
    private var isObserving: Bool
    
    public init(observer: DatabaseManagerObserver) {
        self.observer = observer
        isObserving = false
    }
    
    public func startObserving() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(cancelled), name: DatabaseManager.Notifications.cancelled, object: nil)
        nc.addObserver(self, selector: #selector(progressDidChange), name: DatabaseManager.Notifications.progressDidChange, object: nil)
        nc.addObserver(self, selector: #selector(willLoadDatabase), name: DatabaseManager.Notifications.willLoadDatabase, object: nil)
        nc.addObserver(self, selector: #selector(didLoadDatabase), name: DatabaseManager.Notifications.didLoadDatabase, object: nil)
        nc.addObserver(self, selector: #selector(willSaveDatabase), name: DatabaseManager.Notifications.willSaveDatabase, object: nil)
        nc.addObserver(self, selector: #selector(didSaveDatabase), name: DatabaseManager.Notifications.didSaveDatabase, object: nil)
        nc.addObserver(self, selector: #selector(invalidMasterKey), name: DatabaseManager.Notifications.invalidMasterKey, object: nil)
        nc.addObserver(self, selector: #selector(loadingError), name: DatabaseManager.Notifications.loadingError, object: nil)
        nc.addObserver(self, selector: #selector(savingError), name: DatabaseManager.Notifications.savingError, object: nil)
        nc.addObserver(self, selector: #selector(willCreateDatabase), name: DatabaseManager.Notifications.willCreateDatabase, object: nil)
        nc.addObserver(self, selector: #selector(willCloseDatabase), name: DatabaseManager.Notifications.willCloseDatabase, object: nil)
        nc.addObserver(self, selector: #selector(didCloseDatabase), name: DatabaseManager.Notifications.didCloseDatabase, object: nil)
        isObserving = true
    }
    
    public func stopObserving() {
        guard isObserving else { return }
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.cancelled, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.progressDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.willLoadDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.didLoadDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.willSaveDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.didSaveDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.invalidMasterKey, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.loadingError, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.savingError, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.willCreateDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.willCloseDatabase, object: nil)
        NotificationCenter.default.removeObserver(self, name: DatabaseManager.Notifications.didCloseDatabase, object: nil)
        isObserving = false
    }
    
    
    @objc private func cancelled(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'cancelled': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(database: urlRef, isCancelled: true)
        }
    }

    @objc private func progressDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let progress = userInfo[DatabaseManager.Notifications.userInfoProgressKey] as? ProgressEx else {
                fatalError("DBM notification 'progressDidChange': ProgressEx is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(progressDidChange: progress)
        }
    }

    @objc private func willLoadDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'willLoadDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(willLoadDatabase: urlRef)
        }
    }
    
    @objc private func didLoadDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'didLoadDatabase': URL ref is missing")
        }
        
        guard let warnings = userInfo[DatabaseManager.Notifications.userInfoWarningsKey]
            as? DatabaseLoadingWarnings else
        {
            fatalError("DBM notification 'didLoadDatabase': warnings array is missing")
        }
        
        DispatchQueue.main.async {
            self.observer?.databaseManager(didLoadDatabase: urlRef, warnings: warnings)
        }
    }
    
    @objc private func willSaveDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'willSaveDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(willSaveDatabase: urlRef)
        }
    }
    
    @objc private func didSaveDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'didSaveDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(didSaveDatabase: urlRef)
        }
    }
    
    @objc private func invalidMasterKey(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference,
            let message = userInfo[DatabaseManager.Notifications.userInfoErrorMessageKey] as? String else {
                fatalError("DBM notification 'invalidMasterKey': something is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(database: urlRef, invalidMasterKey: message)
        }
    }
    
    @objc private func loadingError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference,
            let message = userInfo[DatabaseManager.Notifications.userInfoErrorMessageKey] as? String else {
                fatalError("DBM notification 'loadingError': something is missing")
        }
        let reason = userInfo[DatabaseManager.Notifications.userInfoErrorReasonKey] as? String
        DispatchQueue.main.async {
            self.observer?.databaseManager(database: urlRef, loadingError: message, reason: reason)
        }
    }
    
    @objc private func savingError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference,
            let message = userInfo[DatabaseManager.Notifications.userInfoErrorMessageKey] as? String else {
                fatalError("DBM notification 'savingError': something is missing")
        }
        let reason = userInfo[DatabaseManager.Notifications.userInfoErrorReasonKey] as? String
        DispatchQueue.main.async {
            self.observer?.databaseManager(database: urlRef, savingError: message, reason: reason)
        }
    }
    
    @objc private func willCreateDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'willCreateDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(willCreateDatabase: urlRef)
        }
    }

    @objc private func willCloseDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'willCloseDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(willCloseDatabase: urlRef)
        }
    }
    
    @objc private func didCloseDatabase(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[DatabaseManager.Notifications.userInfoURLRefKey] as? URLReference else {
                fatalError("DBM notification 'didCloseDatabase': URL ref is missing")
        }
        DispatchQueue.main.async {
            self.observer?.databaseManager(didCloseDatabase: urlRef)
        }
    }
}
