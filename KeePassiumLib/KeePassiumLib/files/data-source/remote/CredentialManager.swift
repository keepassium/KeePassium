//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum OAuthScope: String, Codable, CaseIterable {
    case fullAccess
    case appFolder
}

public struct OAuthToken: Codable {
    public var accessToken: String
    public var refreshToken: String
    public var accountIdentifier: String?
    public var scope: OAuthScope
    public var acquired: Date
    public var lifespan: TimeInterval
    public var halflife: TimeInterval { lifespan / 2 }

    public init(
        accessToken: String,
        refreshToken: String,
        scope: OAuthScope = .fullAccess,
        acquired: Date,
        lifespan: TimeInterval,
        accountIdentifier: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.scope = scope
        self.acquired = acquired
        self.lifespan = lifespan
        self.accountIdentifier = accountIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case accountIdentifier
        case scope
        case acquired
        case lifespan
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.accountIdentifier = try container.decodeIfPresent(String.self, forKey: .accountIdentifier)
        self.scope = try container.decodeIfPresent(OAuthScope.self, forKey: .scope) ?? .fullAccess
        self.acquired = try container.decode(Date.self, forKey: .acquired)
        self.lifespan = try container.decode(TimeInterval.self, forKey: .lifespan)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(accountIdentifier, forKey: .accountIdentifier)
        try container.encode(scope, forKey: .scope)
        try container.encode(acquired, forKey: .acquired)
        try container.encode(lifespan, forKey: .lifespan)
    }
}

public final class NetworkCredential: Codable {
    public enum CredentialType: Int, Codable {
        case usernamePassword = 0
        case oauthToken = 1
        case anonymous = 2
    }

    private let type: CredentialType
    public let username: String
    public let password: String
    public let allowUntrustedCertificate: Bool
    public let oauthToken: OAuthToken?

    public init(allowUntrustedCertificate: Bool) {
        self.type = .anonymous
        self.username = ""
        self.password = ""
        self.allowUntrustedCertificate = allowUntrustedCertificate
        self.oauthToken = nil
    }

    public init(username: String, password: String, allowUntrustedCertificate: Bool) {
        self.type = .usernamePassword
        self.username = username
        self.password = password
        self.allowUntrustedCertificate = allowUntrustedCertificate
        self.oauthToken = nil
    }

    public init(oauthToken: OAuthToken) {
        self.type = .oauthToken
        self.username = ""
        self.password = ""
        self.allowUntrustedCertificate = false
        self.oauthToken = oauthToken
    }


    internal func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }

    internal static func deserialize(from data: Data) -> NetworkCredential? {
        return try? JSONDecoder().decode(NetworkCredential.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case username
        case password
        case allowUntrustedCertificate
        case oauthToken
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(CredentialType.self, forKey: .type)
            ?? .usernamePassword
        switch type {
        case .usernamePassword:
            self.init(
                username: try container.decode(String.self, forKey: .username),
                password: try container.decode(String.self, forKey: .password),
                allowUntrustedCertificate: try container.decode(
                    Bool.self,
                    forKey: .allowUntrustedCertificate
                )
            )
        case .oauthToken:
            self.init(oauthToken: try container.decode(OAuthToken.self, forKey: .oauthToken))
        case .anonymous:
            self.init(
                allowUntrustedCertificate: try container.decode(
                    Bool.self,
                    forKey: .allowUntrustedCertificate
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch type {
        case .usernamePassword:
            try container.encode(username, forKey: .username)
            try container.encode(password, forKey: .password)
            try container.encode(allowUntrustedCertificate, forKey: .allowUntrustedCertificate)
        case .oauthToken:
            try container.encode(oauthToken, forKey: .oauthToken)
        case .anonymous:
            try container.encode(allowUntrustedCertificate, forKey: .allowUntrustedCertificate)
        }
    }

    public func toURLCredential() -> URLCredential {
        return URLCredential(
            user: username,
            password: password,
            persistence: .none
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
