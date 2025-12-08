//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

struct WebDAVConnectionSetupConfig {
    private let provider: WebDAVProvider

    var serverURL: URL?
    var username: String?
    var password: String?
    var allowUntrusted: Bool

    var showsServerURLField: Bool {
        provider.showsServerURL
    }
    var showsAllowUntrusted: Bool {
        provider.showsAllowUntrusted
    }
    var serverURLPlaceholder: String {
        provider.serverURLPlaceholder ?? "https://host:port/path/"
    }
    var showsFullURLInfo: Bool {
        provider.showsFullURL
    }
    var fullURL: URL? {
        guard let serverURL else { return nil }
        return provider.buildFullURL(from: serverURL, username: username)
    }
    var allowAnonymous: Bool {
        provider.allowsAnonymous
    }
    var showsHelpSection: Bool {
        provider.helpURL != nil
    }
    var helpURL: URL? {
        provider.helpURL
    }
    var helpButtonTitle: String? {
        provider.helpButtonTitle
    }
    var title: String {
        provider.displayName
    }

    var isValid: Bool {
        guard serverURL != nil else { return false }
        if allowAnonymous {
            return true
        } else {
            let hasUsername = username?.isEmpty == false
            let hasPassword = password?.isEmpty == false
            return hasUsername && hasPassword
        }
    }

    init(
        provider: WebDAVProvider,
        serverURL: URL? = nil,
        username: String? = nil,
        password: String? = nil,
        allowUntrusted: Bool = false
    ) {
        self.provider = provider
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.allowUntrusted = allowUntrusted
    }

    static func makeDefault(provider: WebDAVProvider) -> WebDAVConnectionSetupConfig {
        return WebDAVConnectionSetupConfig(
            provider: provider,
            serverURL: provider.defaultServerURL,
            allowUntrusted: false
        )
    }
}

extension NetworkCredential {
    convenience init?(_ config: WebDAVConnectionSetupConfig) {
        let username = config.username ?? ""
        let password = config.password ?? ""
        guard (username.isNotEmpty && password.isNotEmpty) || config.allowAnonymous else {
            return nil
        }
        if username.isEmpty && password.isEmpty {
            self.init(allowUntrustedCertificate: config.allowUntrusted)
        } else {
            self.init(
                username: username,
                password: password,
                allowUntrustedCertificate: config.allowUntrusted
            )
        }
    }
}
