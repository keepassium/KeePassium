//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol FileKeeperObserver: AnyObject {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType)
    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType)
    func fileKeeperDidUpdate()
}

public extension FileKeeperObserver {
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {}
    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {}
}

public class FileKeeperNotifications: Synchronizable {
    private weak var observer: FileKeeperObserver?

    public init(observer: FileKeeperObserver) {
        self.observer = observer
    }

    public func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didAddFile(_:)),
            name: FileKeeperNotifier.fileAddedNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didRemoveFile(_:)),
            name: FileKeeperNotifier.fileRemovedNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didUpdateFileList(_:)),
            name: FileKeeperNotifier.fileListUpdatedNotification,
            object: nil)
    }

    public func stopObserving() {
        NotificationCenter.default.removeObserver(
            self, name: FileKeeperNotifier.fileAddedNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: FileKeeperNotifier.fileRemovedNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: FileKeeperNotifier.fileListUpdatedNotification, object: nil)
    }

    @objc private func didAddFile(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[FileKeeperNotifier.UserInfoKeys.urlReferenceKey] as? URLReference,
            let fileType = userInfo[FileKeeperNotifier.UserInfoKeys.fileTypeKey] as? FileType else {
                fatalError("FileKeeper notification: something is missing")
        }
        dispatchMain { [self] in
            self.observer?.fileKeeper(didAddFile: urlRef, fileType: fileType)
        }
    }

    @objc private func didRemoveFile(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let urlRef = userInfo[FileKeeperNotifier.UserInfoKeys.urlReferenceKey] as? URLReference,
            let fileType = userInfo[FileKeeperNotifier.UserInfoKeys.fileTypeKey] as? FileType else {
                fatalError("FileKeeper notification: something is missing")
        }
        dispatchMain { [self] in
            self.observer?.fileKeeper(didRemoveFile: urlRef, fileType: fileType)
        }
    }

    @objc private func didUpdateFileList(_ notification: Notification) {
        dispatchMain {
            self.observer?.fileKeeperDidUpdate()
        }
    }
}

class FileKeeperNotifier {
    fileprivate static let fileAddedNotification = Notification.Name("com.keepassium.fileKeeper.fileAdded")
    fileprivate static let fileRemovedNotification = Notification.Name("com.keepassium.fileKeeper.fileRemoved")
    fileprivate static let fileListUpdatedNotification =
        Notification.Name("com.keepassium.fileKeeper.fileListUpdated")

    fileprivate enum UserInfoKeys {
        static let urlReferenceKey = "URLReference"
        static let fileTypeKey = "fileType"
    }

    static func notifyFileAdded(urlRef: URLReference, fileType: FileType) {
        NotificationCenter.default.post(
            name: fileAddedNotification,
            object: nil,
            userInfo: [
                UserInfoKeys.urlReferenceKey: urlRef,
                UserInfoKeys.fileTypeKey: fileType
            ]
        )
        notifyFileListUpdated()
    }

    static func notifyFileRemoved(urlRef: URLReference, fileType: FileType) {
        NotificationCenter.default.post(
            name: fileRemovedNotification,
            object: nil,
            userInfo: [
                UserInfoKeys.urlReferenceKey: urlRef,
                UserInfoKeys.fileTypeKey: fileType
            ]
        )
        notifyFileListUpdated()
    }

    static func notifyFileListUpdated() {
        NotificationCenter.default.post(
            name: fileListUpdatedNotification,
            object: nil,
            userInfo: nil)
    }
}
