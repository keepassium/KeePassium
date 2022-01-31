//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

final public class QuickTypeAutoFillStorage {
    static let urlDetector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    public static var isEnabled: Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        ASCredentialIdentityStore.shared.getState { state in
            result = state.isEnabled
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            Diag.error("Failed to query credential store state: timeout")
        }
        return result
    }
    
    public static func removeAll() {
        let store = ASCredentialIdentityStore.shared
        store.getState { state in
            guard state.isEnabled else {
                return
            }
            store.removeAllCredentialIdentities { (success, error) in
                if let error = error {
                    Diag.error("Failed to remove identities [message: \(error.localizedDescription)]")
                } else {
                    Diag.debug("QuickType AutoFill data removed")
                }
            }
        }
    }

    public static func removeIdentities(in databaseFile: DatabaseFile) {
        let identities = getCredentialIdentities(from: databaseFile)
        removeIdentities(identities)
    }
    
    public static func removeIdentities(_ identities: [ASPasswordCredentialIdentity]) {
        ASCredentialIdentityStore.shared.removeCredentialIdentities(identities) {
            (success, error) in
            if let error = error {
                Diag.error("Failed to remove QuickType AutoFill data [message: \(error.localizedDescription)]")
            } else {
                Diag.debug("QuickType AutoFill data removed")
            }
        }
    }

    static func saveIdentities(from databaseFile: DatabaseFile, replaceExisting: Bool) {
        guard Settings.current.isQuickTypeEnabled else {
            Diag.debug("QuickType AutoFill disabled, skipping")
            return
        }
        Diag.debug("Updating QuickType AutoFill data")
        let store = ASCredentialIdentityStore.shared
        store.getState { state in
            guard state.isEnabled else {
                return
            }
            let identities = self.getCredentialIdentities(from: databaseFile)
            let completion: ((Bool, Error?) -> Void) = { (success, error) in
                if let error = error {
                    Diag.error("Failed to save QuickType AutoFill data [message: \(error.localizedDescription)]")
                } else {
                    Diag.debug("QuickType AutoFill data saved")
                }
            }
            if replaceExisting {
                store.replaceCredentialIdentities(with: identities, completion: completion)
            } else {
                store.saveCredentialIdentities(identities, completion: completion)
            }
        }
    }
    
    private static func getCredentialIdentities(
        from databaseFile: DatabaseFile
    ) -> [ASPasswordCredentialIdentity] {
        var result = [ASPasswordCredentialIdentity]()
        let rootGroup = databaseFile.database.root
        rootGroup?.applyToAllChildren(groupHandler: nil, entryHandler: { entry in
            guard (entry.parent as? Group2)?.isSearchingEnabled ?? true else {
                return
            }
            if entry.isDeleted || entry.isHiddenFromSearch || entry.isExpired {
                return
            }
            if let serviceIDs = entry.extractSearchableData()?.toCredentialServiceIdentifiers() {
                let recordID = QuickTypeAutoFillRecord(context: databaseFile, itemID: entry.uuid)
                let entryCredentialIdentities = makeCredentialIdentities(
                    userName: entry.resolvedUserName,
                    services: serviceIDs,
                    record: recordID
                )
                result.append(contentsOf: entryCredentialIdentities)
            }
        })
        return result
    }
    
    private static func makeCredentialIdentities(
        userName: String,
        services: [ASCredentialServiceIdentifier],
        record: QuickTypeAutoFillRecord
    ) -> [ASPasswordCredentialIdentity] {
        guard userName.isNotEmpty else {
            return []
        }
        let recordIdentifier = record.toString()
        return services.map {
            ASPasswordCredentialIdentity(
                serviceIdentifier: $0,
                user: userName,
                recordIdentifier: recordIdentifier
            )
        }
    }
}

private struct SearchableData {
    var urls = Set<URL>()
    var domains = Set<String>()

    mutating func maybeAdd(url: URL?) {
        if let url = url {
            urls.insert(url)
        }
    }
    mutating func maybeAdd(domain: String?) {
        if let domain = domain {
            domains.insert(domain)
        }
    }
    
    func toCredentialServiceIdentifiers() -> [ASCredentialServiceIdentifier] {
        let urlBasedPart = urls.map { url in
            ASCredentialServiceIdentifier(identifier: url.absoluteString, type: .URL)
        }
        let domainBasedPart = domains.map { domain in
            ASCredentialServiceIdentifier(identifier: domain, type: .domain)
        }
        
        if urlBasedPart.isEmpty && domainBasedPart.isEmpty {
            return []
        }
        var result = [ASCredentialServiceIdentifier]()
        result.append(contentsOf: urlBasedPart)
        result.append(contentsOf: domainBasedPart)
        return result
    }
}

extension Entry {
    fileprivate func extractSearchableData() -> SearchableData? {
        if isHiddenFromSearch {
            return nil
        }
        
        var result = SearchableData()
        result.maybeAdd(url: URL.from(malformedString: resolvedURL))
        guard let entry2 = self as? Entry2 else {
            return result
        }

        let customFields = entry2.fields.filter { !$0.isStandardField}
        customFields.forEach {
            let maybeURL = URL.from(malformedString: $0.resolvedValue)
            result.maybeAdd(url: maybeURL)
        }
        return result
    }
}
