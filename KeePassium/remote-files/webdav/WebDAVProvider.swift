//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

struct WebDAVProvider {
    static let allCases: [Self] = [
        .genericWebDAV,
        .genericHTTP,
        .hetzner,
        .hiDriveIonos,
        .hiDriveStrato,
        .koofr,
        .nextcloud,
        .owncloud,
        .synology,
        .woelkli,
    ]

    let displayName: String
    let defaultServerURL: URL?
    let serverURLPlaceholder: String?
    let showsServerURL: Bool
    let showsAllowUntrusted: Bool
    let showsFullURL: Bool
    let pathPrefix: String?
    let allowsAnonymous: Bool
    let helpURL: URL?
    let helpButtonTitle: String?

    static let genericWebDAV = WebDAVProvider(
        displayName: LString.connectionTypeWebDAV,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://host:port/path/",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: true,
        pathPrefix: nil,
        helpURL: nil,
        helpButtonTitle: nil
    )

    static let genericHTTP = WebDAVProvider(
        displayName: LString.connectionTypeHTTP,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://host:port/path/file.kdbx",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: false,
        pathPrefix: nil,
        allowsAnonymous: true,
        helpURL: nil,
        helpButtonTitle: nil
    )

    static let hetzner = WebDAVProvider(
        displayName: LString.connectionTypeHetzner,
        defaultServerURL: URL(string: "https://%25username%25.your-storagebox.de"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: true,
        pathPrefix: nil,
        helpURL: URL(string: "https://docs.hetzner.com/storage/storage-box/access/access-webdav/"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeHetzner
        )
    )

    static let hiDriveIonos = WebDAVProvider(
        displayName: LString.connectionTypeHiDriveIonos,
        defaultServerURL: URL(
            string: "https://%25username%25.webdav.hidrive.ionos.com"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: true,
        pathPrefix: nil,
        helpURL: URL(string: "https://www.ionos.com/help/cloud-storage/setting-up-hidrive-on-your-devices/connecting-to-hidrive-using-webdav-windows-10/11/"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeHiDriveIonos
        )
    )

    static let hiDriveStrato = WebDAVProvider(
        displayName: LString.connectionTypeHiDriveStrato,
        defaultServerURL: URL(string: "https://webdav.hidrive.strato.com"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: false,
        pathPrefix: nil,
        helpURL: URL(string: "https://www.strato.de/faq/cloud-speicher/ueber-welche-protokolle-kann-ich-mich-mit-hidrive-verbinden/"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeHiDriveStrato
        )
    )

    static let koofr = WebDAVProvider(
        displayName: LString.connectionTypeKoofr,
        defaultServerURL: URL(string: "https://app.koofr.net"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: false,
        pathPrefix: "/dav/Koofr",
        helpURL: URL(string: "https://koofr.eu/help/koofr_with_webdav/how-do-i-connect-a-service-to-koofr-through-webdav/"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeKoofr
        )
    )

    static let magentaCloud = WebDAVProvider(
        displayName: LString.connectionTypeMagentaCloud,
        defaultServerURL: URL(string: "https://magentacloud.de"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: false,
        pathPrefix: "/remote.php/webdav",
        helpURL: URL(string: "https://cloud.telekom-dienste.de/hilfe#einrichten"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeMagentaCloud
        )
    )

    static let nextcloud = WebDAVProvider(
        displayName: LString.connectionTypeNextcloud,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://nextcloud.example.com/",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: true,
        pathPrefix: "/remote.php/dav/files/%username%/",
        helpURL: URL(string: "https://docs.nextcloud.com/server/latest/user_manual/en/files/access_webdav.html"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeNextcloud
        )
    )

    static let owncloud = WebDAVProvider(
        displayName: LString.connectionTypeOwnCloud,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://owncloud.example.com/",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: true,
        pathPrefix: "/remote.php/dav/files/%username%/",
        helpURL: URL(string: "https://doc.owncloud.com/server/next/classic_ui/files/access_webdav.html"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeOwnCloud
        )
    )

    static let qnap = WebDAVProvider(
        displayName: LString.connectionTypeQNAP,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://example.myqnapcloud.com:5001/home",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: true,
        pathPrefix: nil,
        helpURL: URL(string: "https://www.qnap.com/en/how-to/tutorial/article/accessing-your-qnap-nas-remotely-with-webdav"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeQNAP
        )
    )
    static let synology = WebDAVProvider(
        displayName: LString.connectionTypeSynology,
        defaultServerURL: nil,
        serverURLPlaceholder: "https://synologynas:5006/",
        showsServerURL: true,
        showsAllowUntrusted: true,
        showsFullURL: true,
        pathPrefix: nil,
        helpURL: URL(string: "https://kb.synology.com/en-global/DSM/tutorial/How_to_access_files_on_Synology_NAS_with_WebDAV"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeSynology
        )
    )

    static let woelkli = WebDAVProvider(
        displayName: LString.connectionTypeWoelkli,
        defaultServerURL: URL(string: "https://cloud.woelkli.com"),
        serverURLPlaceholder: nil,
        showsServerURL: false,
        showsAllowUntrusted: false,
        showsFullURL: false,
        pathPrefix: "/remote.php/dav/files/%username%/",
        helpURL: URL(string: "https://woelkli.com/en/faq"),
        helpButtonTitle: String.localizedStringWithFormat(
            LString.titleWebDAVServiceSetupGuideTemplate,
            LString.connectionTypeWoelkli
        )
    )

    private init(
        displayName: String,
        defaultServerURL: URL?,
        serverURLPlaceholder: String?,
        showsServerURL: Bool,
        showsAllowUntrusted: Bool,
        showsFullURL: Bool,
        pathPrefix: String?,
        allowsAnonymous: Bool = false,
        helpURL: URL?,
        helpButtonTitle: String?
    ) {
        self.displayName = displayName
        self.defaultServerURL = defaultServerURL
        self.serverURLPlaceholder = serverURLPlaceholder
        self.showsServerURL = showsServerURL
        self.showsAllowUntrusted = showsAllowUntrusted
        self.showsFullURL = showsFullURL
        self.pathPrefix = pathPrefix
        self.allowsAnonymous = allowsAnonymous
        self.helpURL = helpURL
        self.helpButtonTitle = helpButtonTitle
    }

    init(from connectionType: RemoteConnectionType) {
        assert(connectionType.fileProvider == .keepassiumWebDAV)
        switch connectionType {
        case .genericWebDAV: self = .genericWebDAV
        case .genericHTTP: self = .genericHTTP
        case .hetzner: self = .hetzner
        case .hiDriveIonos: self = .hiDriveIonos
        case .hiDriveStrato: self = .hiDriveStrato
        case .koofr: self = .koofr
        case .nextcloud: self = .nextcloud
        case .magentaCloud: self = .magentaCloud
        case .owncloud: self = .owncloud
        case .qnap: self = .qnap
        case .synology: self = .synology
        case .woelkli: self = .woelkli
        default:
            assertionFailure("Unmapped WebDAV service: \(connectionType)")
            self = .genericWebDAV
        }
    }

    func buildFullURL(from baseURL: URL, username: String?) -> URL {
        guard let pathPrefix else {
            guard let username, !username.isEmpty else {
                return URL(string: baseURL.absoluteString.replacingOccurrences(of: "%25username%25", with: "username"))!
            }
            return URL(string: baseURL.absoluteString.replacingOccurrences(of: "%25username%25", with: username))!
        }

        let expandedPrefix = pathPrefix.replacingOccurrences(of: "%username%", with: username ?? "")

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? "/"
        let normalizedBase = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPrefix = expandedPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if normalizedBase.isEmpty {
            components?.path = "/\(normalizedPrefix)"
        } else {
            components?.path = "/\(normalizedBase)/\(normalizedPrefix)"
        }

        return components?.url ?? baseURL
    }
}
