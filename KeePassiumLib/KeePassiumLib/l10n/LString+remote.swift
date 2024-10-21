//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
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
    public static let connectionTypeOneDrive = "OneDrive"
    public static let connectionTypeOneDrivePersonal = connectionTypeOneDrive
    public static let connectionTypeSharePoint = "SharePoint"
    public static let connectionTypeOneDriveForBusiness = NSLocalizedString(
        "[StorageService/OneDriveForBusiness/title]",
        bundle: Bundle.framework,
        value: "OneDrive for Business",
        comment: "Name of a cloud storage service. Must match Microsoft's translation, see  https://partner.microsoft.com/solutions/onedrive-for-business")
    public static let connectionTypeDropbox = "Dropbox"
    public static let connectionTypeDropboxBusiness = NSLocalizedString(
        "[StorageService/DropboxBusiness/title]",
        bundle: Bundle.framework,
        value: "Dropbox Business",
        comment: "Name of a cloud storage service")
    public static let connectionTypeDropboxPro = NSLocalizedString(
        "[StorageService/DropboxPro/title]",
        bundle: Bundle.framework,
        value: "Dropbox Pro",
        comment: "Name of a cloud storage service")
    public static let connectionTypeGoogleDrive = "Google Drive"
    public static let connectionTypeGoogleWorkspace = NSLocalizedString(
        "[StorageService/GoogleWorkspace/title]",
        bundle: Bundle.framework,
        value: "Google Workspace",
        comment: "Name of a cloud storage service")
    public static let connectionTypeOtherLocations = NSLocalizedString(
        "[StorageService/OtherServices/title]",
        bundle: Bundle.framework,
        value: "Other Services",
        comment: "Title of a file storage service option (for example: Dropbox, OneDrive, Other Services)")

    public static let titleConnection = NSLocalizedString(
        "[RemoteConnection/Connection/title]",
        bundle: Bundle.framework,
        value: "Connection",
        comment: "Network connection. For example `Connection: WebDAV` or `Connection: MyCloud`.")
    public static let directConnectionDescription = NSLocalizedString(
        "[RemoteConnection/Direct/description]",
        bundle: Bundle.framework,
        value: "KeePassium will communicate directly with your online storage. This ensures reliable file transfer.",
        comment: "Description of the `Direct connection` sync method.")
    public static let integrationViaFilesAppDescription = NSLocalizedString(
        "[RemoteConnection/ViaFilesApp/description]",
        bundle: Bundle.framework,
        value: "KeePassium will assign file synchronization to the app of your storage provider. Some apps work better than others.",
        comment: "Description of the `Integration via Files app` sync method.")

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

    public static let titleServerURL = NSLocalizedString(
        "[RemoteConnection/ServerURL]",
        bundle: Bundle.framework,
        value: "Server URL",
        comment: "Network address of a WebDAV server")
    public static let titleCredentials = NSLocalizedString(
        "[RemoteConnection/Credentials]",
        bundle: Bundle.framework,
        value: "Credentials",
        comment: "Title of a section: username, password, etc")

    public static let titleFolderIsEmpty = NSLocalizedString(
        "[General/FileList/Empty/title]",
        bundle: Bundle.framework,
        value: "Folder is empty",
        comment: "Placeholder for folders without files")

    public static let titlePrivateBrowserMode = NSLocalizedString(
        "[RemoteConnection/SignIn/PrivateMode/title]",
        bundle: Bundle.framework,
        value: "Private mode",
        comment: "")
    public static let descriptionPrivateBrowserMode = NSLocalizedString(
        "[RemoteConnection/SignIn/PrivateMode/description]",
        bundle: Bundle.framework,
        value: "Open sign-in page in private web browser mode",
        comment: "")

    public static let actionSignInToOneDrive = NSLocalizedString(
        "[RemoteConnection/SignIn/OneDrive/action]",
        bundle: Bundle.framework,
        value: "Sign in to OneDrive",
        comment: "Action: authenticate to OneDrive account")
    public static let titleOneDriveRequiresSignIn = NSLocalizedString(
        "[RemoteConnection/SignIn/OneDrive/authorizationRequried]",
        bundle: Bundle.framework,
        value: "OneDrive needs you to sign in again.",
        comment: "Error description: the user should manually sign in to their OneDrive account")

    public static let titleOneDriveFolderFiles = NSLocalizedString(
        "[RemoteConnection/OneDrive/Folder/files]",
        bundle: Bundle.framework,
        value: "Files",
        comment: "Name of a predefined OneDrive folder which contains user's own files")
    public static let titleOneDriveFolderSharedWithMe = NSLocalizedString(
        "[RemoteConnection/OneDrive/Folder/sharedWithMe]",
        bundle: Bundle.framework,
        value: "Shared",
        comment: "Name of a predefined OneDrive folder which contains files shared with this user")

    public static let titleDropboxRequiresSignIn = NSLocalizedString(
        "[RemoteConnection/SignIn/Dropbox/authorizationRequried]",
        bundle: Bundle.framework,
        value: "Dropbox needs you to sign in again.",
        comment: "Error description: the user should manually sign in to their Dropbox account")
    public static let actionSignInToDropbox = NSLocalizedString(
        "[RemoteConnection/SignIn/Dropbox/action]",
        bundle: Bundle.framework,
        value: "Sign in to Dropbox",
        comment: "Action: authenticate to Dropbox account")

    public static let titleGoogleDriveRequiresSignIn = NSLocalizedString(
        "[RemoteConnection/SignIn/GoogleDrive/authorizationRequried]",
        bundle: Bundle.framework,
        value: "Google Drive needs you to sign in again.",
        comment: "Error description: the user should manually sign in to their Google Drive account")
    public static let actionSignInToGoogleDrive = NSLocalizedString(
        "[RemoteConnection/SignIn/GoogleDrive/action]",
        bundle: Bundle.framework,
        value: "Sign in to Google Drive",
        comment: "Action: authenticate to Google Drive account")
    public static let titleGoogleDriveFolderMyDrive = NSLocalizedString(
        "[RemoteConnection/GoogleDrive/Folder/myDrive]",
        bundle: Bundle.framework,
        value: "My Drive",
        comment: "Name of a predefined Google Drive folder which contains user's own files")
    public static let titleGoogleDriveFolderSharedWithMe = NSLocalizedString(
        "[RemoteConnection/GoogleDrive/Folder/sharedWithMe]",
        bundle: Bundle.framework,
        value: "Shared With Me",
        comment: "Name of a predefined GoogleDrive folder which contains files shared with this user")

}
// swiftlint:enable line_length
