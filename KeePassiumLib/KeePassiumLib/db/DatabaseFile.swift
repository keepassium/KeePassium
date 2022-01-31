//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


public class DatabaseFile: Eraseable {
    
    public enum ConflictResolutionStrategy {
        case cancelSaving
        case overwriteRemote
        case saveAs
        case merge
    }
    
    public enum StatusFlag {
        case readOnly
        case localFallback
    }
    public typealias Status = Set<StatusFlag>
    
    public let database: Database
       
    public private(set) var data: ByteArray
    
    public private(set) var storedDataSHA512: ByteArray
    
    public var fileURL: URL

    public var fileReference: URLReference?
    
    public private(set) var status: Status

    public var visibleFileName: String {
        return fileURL.lastPathComponent
    }

    public var descriptor: URLReference.Descriptor? {
        return fileReference?.getDescriptor()
    }
    
    private var _fileProvider: FileProvider?
    public var fileProvider: FileProvider? {
        get {
            return fileReference?.fileProvider ?? _fileProvider
        }
        set {
            _fileProvider = newValue
        }
    }
    
    init(
        database: Database,
        data: ByteArray = ByteArray(),
        fileURL: URL,
        fileProvider: FileProvider?,
        status: Status
    ) {
        self.database = database
        self.data = data
        self.storedDataSHA512 = data.sha512
        self.fileURL = fileURL
        self._fileProvider = fileProvider
        self.fileReference = nil
        self.status = status
    }

    init(
        database: Database,
        data: ByteArray = ByteArray(),
        fileURL: URL,
        fileReference: URLReference,
        status: Status
    ) {
        self.database = database
        self.data = data
        self.storedDataSHA512 = data.sha512
        self.fileURL = fileURL
        self.fileReference = fileReference
        self._fileProvider = nil 
        self.status = status
    }
    
    public func erase() {
        data.erase()
        database.erase()
        status.removeAll()
    }
    
    public func resolveFileURL(
        timeout: TimeInterval = URLReference.defaultTimeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping (() -> Void)
    ) {
        guard let fileReference = fileReference else {
            completion()
            return
        }
        fileReference.resolveAsync(timeout: timeout, callbackQueue: completionQueue) { result in
            switch result {
            case .success(let resolvedURL):
                self.fileURL = resolvedURL
            case .failure(let fileAccessError):
                Diag.error("Failed to resolve file reference [message: \(fileAccessError.localizedDescription)]")
            }
            completion()
        }
    }
    
    public func setData(_ data: ByteArray, updateHash: Bool) {
        self.data = data.clone()
        if updateHash {
            storedDataSHA512 = data.sha512
        }
    }
}
