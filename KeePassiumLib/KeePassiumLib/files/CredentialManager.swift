//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation


public final class NetworkCredential: Codable {
    public let username: String
    public let password: String
    public let allowUntrustedCertificate: Bool
    
    public init(username: String, password: String, allowUntrustedCertificate: Bool) {
        self.username = username
        self.password = password
        self.allowUntrustedCertificate = allowUntrustedCertificate
    }
    
    internal func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }
    
    internal static func deserialize(from data: Data) -> NetworkCredential? {
        return try? JSONDecoder().decode(NetworkCredential.self, from: data)
    }
    
    public func toURLCredential() -> URLCredential {
        return URLCredential(
            user: username,
            password: password,
            persistence: .forSession
        )
    }
}

public final class CredentialManager {
    public static let shared = CredentialManager()
    
    private init() {
    }
    
    public func get(for url: URL) -> NetworkCredential? {
        do {
            return try Keychain.shared.getNetworkCredential(for: url)
        } catch {
            Diag.error("Failed to get network credential [message: \(error.localizedDescription)]")
            return nil
        }
    }
    
    public func store(credential: NetworkCredential, for url: URL) {
        do {
            try Keychain.shared.store(networkCredential: credential, for: url)
        } catch {
            Diag.error("Failed to store network credential [message: \(error.localizedDescription)]")
        }
    }
    
    public func remove(for url: URL) {
        do {
            try Keychain.shared.removeNetworkCredential(for: url)
        } catch {
            Diag.error("Failed to remove network credential [message: \(error.localizedDescription)]")
        }
    }
    
    public func removeAll() {
        do {
            try Keychain.shared.removeAllNetworkCredentials() 
        } catch {
            Diag.error("Failed to remove network credentials [message: \(error.localizedDescription)]")
        }
    }
}
