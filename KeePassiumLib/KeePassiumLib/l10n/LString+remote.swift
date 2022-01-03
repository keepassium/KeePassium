//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {

    public static let actionConnectToServer = NSLocalizedString(
        "[RemoteConnection/connectToServer]",
        bundle: Bundle.framework,
        value: "Connect to Server",
        comment: "Action: connect to a network server ")

    public static let titleRemoteConnection = NSLocalizedString(
        "[RemoteConnection/title]",
        bundle: Bundle.framework,
        value: "Remote Connection",
        comment: "Title: connection to a network storage")

    public static let errorAuthenticationFailed = NSLocalizedString(
        "[RemoteConnection/Error/AuthenticationFailed/title]",
        bundle: Bundle.framework,
        value: "Authentication failed",
        comment: "Error message: user credentials rejected by the server"
    )
    
    public static let connectionTypeWebDAV = "WebDAV" 
    public static let titleConnection = NSLocalizedString(
        "[RemoteConnection/Connection/title]",
        bundle: Bundle.framework,
        value: "Connection",
        comment: "Network connection. For example `Connection: WebDAV` or `Connection: MyCloud`.")
    
    public static let titleAllowUntrustedCertificate = NSLocalizedString(
        "[RemoteConnection/AllowUntrusted/title]",
        bundle: Bundle.framework,
        value: "Allow Untrusted Certificate",
        comment: "Network security setting")
    
    public static let titleFileURL = NSLocalizedString(
        "[RemoteConnection/FileURL]",
        bundle: Bundle.framework,
        value: "File URL",
        comment: "Network address of a file")
    public static let titleCredentials = NSLocalizedString(
        "[RemoteConnection/Credentials]",
        bundle: Bundle.framework,
        value: "Credentials",
        comment: "Title of a section: username, password, etc")
}
