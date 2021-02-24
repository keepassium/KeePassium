//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public struct FileInfo {
    public var fileName: String
    public var fileSize: Int64?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var isExcludedFromBackup: Bool?
    public var isInTrash: Bool
}

public class URLReference:
    Equatable,
    Hashable,
    Codable,
    CustomDebugStringConvertible,
    Synchronizable
{
    public typealias Descriptor = String
    
    public enum Location: Int, Codable, CustomStringConvertible {
        public static let allValues: [Location] =
            [.internalDocuments, .internalBackup, .internalInbox, .external]
        
        public static let allInternal: [Location] =
            [.internalDocuments, .internalBackup, .internalInbox]
        
        case internalDocuments = 0
        case internalBackup = 1
        case internalInbox = 2
        case external = 100
        
        public var isInternal: Bool {
            return self != .external
        }
        
        public var description: String {
            switch self {
            case .internalDocuments:
                return NSLocalizedString(
                    "[URLReference/Location] Local copy",
                    bundle: Bundle.framework,
                    value: "Local copy",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. Example: 'File Location: Local copy'")
            case .internalInbox:
                return NSLocalizedString(
                    "[URLReference/Location] Internal inbox",
                    bundle: Bundle.framework,
                    value: "Internal inbox",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. 'Inbox' is a special directory for files that are being imported. Can be also 'Internal import'. Example: 'File Location: Internal inbox'")
            case .internalBackup:
                return NSLocalizedString(
                    "[URLReference/Location] Internal backup",
                    bundle: Bundle.framework,
                    value: "Internal backup",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. 'Backup' is a dedicated directory for database backup files. Example: 'File Location: Internal backup'")
            case .external:
                return NSLocalizedString(
                    "[URLReference/Location] Cloud storage / Another app",
                    bundle: Bundle.framework,
                    value: "Cloud storage / Another app",
                    comment: "Human-readable file location. The file is situated either online / in cloud storage, or on the same device, but in some other app. Example: 'File Location: Cloud storage / Another app'")
            }
        }
    }
    
    public static let defaultTimeout: TimeInterval = 15.0
    
    public var visibleFileName: String { return url?.lastPathComponent ?? "?" }
    
    public private(set) var error: FileAccessError?
    public var hasError: Bool { return error != nil}
    
    public var hasPermissionError257: Bool {
        guard let nsError = error?.underlyingError as NSError? else { return false }
        return (nsError.domain == NSCocoaErrorDomain) && (nsError.code == 257)
    }
    
    public var hasFileMissingError: Bool {
        guard location == .external,
              let underlyingError = error?.underlyingError,
              let nsError = underlyingError as NSError? else { return false }
        
        #if targetEnvironment(macCatalyst)
            switch nsError.domain {
            case NSCocoaErrorDomain:
                return nsError.code == CocoaError.Code.fileNoSuchFile.rawValue
            default:
                return false
            }
        #else
            switch nsError.domain {
            case NSCocoaErrorDomain:
                return nsError.code == CocoaError.Code.fileNoSuchFile.rawValue
            case NSFileProviderErrorDomain:
                return nsError.code == NSFileProviderError.noSuchItem.rawValue
            default:
                return false
            }
        #endif
    }
    
    private let data: Data
    public let location: Location
    
    internal var bookmarkedURL: URL?
    internal var cachedURL: URL?
    internal var resolvedURL: URL?
    
    internal var originalURL: URL? {
        return bookmarkedURL ?? cachedURL
    }

    internal var url: URL? {
        return resolvedURL ?? cachedURL ?? bookmarkedURL
    }
    
    
    public var isRefreshingInfo: Bool {
        let result = synchronized {
            return (self.infoRefreshRequestCount > 0)
        }
        return result
    }

    private var infoRefreshRequestCount = 0

    private var cachedInfo: FileInfo?
    
    
    public private(set) var fileProvider: FileProvider?
    
    fileprivate static let backgroundQueue = DispatchQueue(
        label: "com.keepassium.URLReference",
        qos: .background,
        attributes: [.concurrent])
    
    
    
    private enum CodingKeys: String, CodingKey {
        case data = "data"
        case location = "location"
        case cachedURL = "url"
    }
    
    
    public init(from url: URL, location: Location) throws {
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        cachedURL = url
        bookmarkedURL = url
        self.location = location
        if location.isInternal {
            data = Data() 
        } else {
            data = try url.bookmarkData(
                options: URLReference.getBookmarkCreationOptions(),
                includingResourceValuesForKeys: nil,
                relativeTo: nil) 
        }
        processReference()
    }

    private static func getBookmarkCreationOptions() -> URL.BookmarkCreationOptions {
        if ProcessInfo.isRunningOnMac {
            return []
        } else {
            return [.minimalBookmark]
        }
    }
    
    public static func == (lhs: URLReference, rhs: URLReference) -> Bool {
        guard lhs.location == rhs.location else { return false }
        guard let lhsOriginalURL = lhs.originalURL, let rhsOriginalURL = rhs.originalURL else {
            assertionFailure()
            Diag.debug("Original URL of the file is nil.")
            return false
        }
        return lhsOriginalURL == rhsOriginalURL
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(location)
        guard let originalURL = originalURL else {
            assertionFailure()
            return
        }
        hasher.combine(originalURL)
    }
    
    public func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }
    
    public static func deserialize(from data: Data) -> URLReference? {
        guard let ref = try? JSONDecoder().decode(URLReference.self, from: data) else {
            return nil
        }
        ref.processReference()
        return ref
    }
    
    public var debugDescription: String {
        return " ‣ Location: \(location)\n" +
            " ‣ bookmarkedURL: \(bookmarkedURL?.relativeString ?? "nil")\n" +
            " ‣ cachedURL: \(cachedURL?.relativeString ?? "nil")\n" +
            " ‣ resolvedURL: \(resolvedURL?.relativeString ?? "nil")\n" +
            " ‣ fileProvider: \(fileProvider?.id ?? "nil")\n" +
            " ‣ data: \(data.count) bytes"
    }
    
    
    public typealias CreateCallback = (Result<URLReference, FileAccessError>) -> ()

    public static func create(
        for url: URL,
        location: URLReference.Location,
        completion callback: @escaping CreateCallback)
    {
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if tryCreate(for: url, location: location, callbackOnError: false, callback: callback) {
            print("URL bookmarked on stage 1")
            return
        }

        let tmpDoc = BaseDocument(fileURL: url, fileProvider: nil)
        tmpDoc.open(withTimeout: URLReference.defaultTimeout) { (result) in
            defer {
                tmpDoc.close(completionHandler: nil)
            }
            switch result {
            case .success(_):
                tryCreate(for: url, location: location, callbackOnError: true, callback: callback)
            case .failure(let fileAccessError):
                DispatchQueue.main.async {
                    callback(.failure(fileAccessError))
                }
            }
        }
    }
    
    @discardableResult
    private static func tryCreate(
        for url: URL,
        location: URLReference.Location,
        callbackOnError: Bool = false,
        callback: @escaping CreateCallback
    ) -> Bool {
        do {
            let urlRef = try URLReference(from: url, location: location)
            DispatchQueue.main.async {
                callback(.success(urlRef))
            }
            return true
        } catch {
            if callbackOnError {
                DispatchQueue.main.async {
                    let fileAccessError = FileAccessError.make(from: error, fileProvider: nil)
                    callback(.failure(fileAccessError))
                }
            }
            return false
        }
    }
    
    
    public typealias ResolveCallback = (Result<URL, FileAccessError>) -> ()
    
    public func resolveAsync(
        timeout: TimeInterval = URLReference.defaultTimeout,
        callback: @escaping ResolveCallback)
    {
        execute(
            withTimeout: URLReference.defaultTimeout,
            on: URLReference.backgroundQueue,
            slowSyncOperation: { () -> Result<URL, Error> in
                do {
                    let url = try self.resolveSync()
                    return .success(url)
                } catch {
                    return .failure(error)
                }
            },
            onSuccess: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let url):
                    self.error = nil
                    self.dispatchMain {
                        callback(.success(url))
                    }
                case .failure(let error):
                    let fileAccessError = FileAccessError.make(
                        from: error,
                        fileProvider: self.fileProvider
                    )
                    self.error = fileAccessError
                    self.dispatchMain {
                        callback(.failure(fileAccessError))
                    }
                }
            },
            onTimeout: { [self] in
                self.error = FileAccessError.timeout(fileProvider: self.fileProvider)
                self.dispatchMain {
                    callback(.failure(FileAccessError.timeout(fileProvider: self.fileProvider)))
                }
            }
        )
    }
    
    
    public typealias InfoCallback = (Result<FileInfo, FileAccessError>) -> ()
    
    private enum InfoRefreshRequestState {
        case added
        case completed
    }
    
    private func registerInfoRefreshRequest(_ state: InfoRefreshRequestState) {
        synchronized { [self] in
            switch state {
            case .added:
                self.infoRefreshRequestCount += 1
            case .completed:
                self.infoRefreshRequestCount -= 1
            }
        }
    }
    
    public func getCachedInfo(canFetch: Bool, completion callback: @escaping InfoCallback) {
        if let info = cachedInfo {
            DispatchQueue.main.async {
                callback(.success(info))
            }
        } else {
            guard canFetch else {
                let error: FileAccessError = self.error ?? .noInfoAvailable
                callback(.failure(error))
                return
            }
            refreshInfo(completion: callback)
        }
    }
    
    
    public func refreshInfo(
        timeout: TimeInterval = URLReference.defaultTimeout,
        completion callback: @escaping InfoCallback)
    {
        registerInfoRefreshRequest(.added)
        resolveAsync(timeout: timeout) {
            [self] (result) in 
            switch result {
            case .success(let url):
                URLReference.backgroundQueue.async { 
                    self.refreshInfo(for: url, completion: callback)
                }
            case .failure(let error):
                self.registerInfoRefreshRequest(.completed)
                self.error = error
                callback(.failure(error))
            }
        }
    }
    
    private func refreshInfo(for url: URL, completion callback: @escaping InfoCallback) {
        assert(!Thread.isMainThread)

        let isAccessed = url.startAccessingSecurityScopedResource()
        
        let tmpDoc = BaseDocument(fileURL: url, fileProvider: fileProvider)
        tmpDoc.open(withTimeout: URLReference.defaultTimeout) { [self] (result) in
            defer {
                if isAccessed {
                    url.stopAccessingSecurityScopedResource()
                }
                tmpDoc.close(completionHandler: nil)
            }
            self.registerInfoRefreshRequest(.completed)
            switch result {
            case .success(_):
                self.readFileInfo(url: url, completion: callback)
            case .failure(let fileAccessError):
                DispatchQueue.main.async { 
                    self.error = fileAccessError
                    callback(.failure(fileAccessError))
                }
            }
        }
    }
    
    private func readFileInfo(url: URL, completion callback: @escaping InfoCallback) {
        assert(!Thread.isMainThread)
        let attributeKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .isExcludedFromBackupKey,
            .ubiquitousItemDownloadingStatusKey,
        ]

        var urlWithFreshAttributes = url
        urlWithFreshAttributes.removeAllCachedResourceValues()
        
        let attributes: URLResourceValues
        do {
            attributes = try urlWithFreshAttributes.resourceValues(forKeys: attributeKeys)
        } catch {
            Diag.error("Failed to get file info [reason: \(error.localizedDescription)]")
            let fileAccessError = FileAccessError.systemError(error)
            DispatchQueue.main.async { 
                self.error = fileAccessError
                callback(.failure(fileAccessError))
            }
            return
        }
        
        let latestInfo = FileInfo(
            fileName: urlWithFreshAttributes.lastPathComponent,
            fileSize: Int64(attributes.fileSize ?? -1),
            creationDate: attributes.creationDate,
            modificationDate: attributes.contentModificationDate,
            isExcludedFromBackup: attributes.isExcludedFromBackup ?? false,
            isInTrash: url.isInTrashDirectory)
        self.cachedInfo = latestInfo
        DispatchQueue.main.async {
            self.error = nil
            callback(.success(latestInfo))
        }
    }
    
    
    public func resolveSync() throws -> URL {
        if location.isInternal, let cachedURL = self.cachedURL {
            return cachedURL
        }
        
        var isStale = false
        let _resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: [URL.BookmarkResolutionOptions.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        self.resolvedURL = _resolvedURL
        return _resolvedURL
    }
    
    public func getDescriptor() -> Descriptor? {
        if let resolvedFileName = resolvedURL?.lastPathComponent {
            return resolvedFileName
        }
        if let cachedFileName = cachedURL?.lastPathComponent {
            return cachedFileName
        }
        return bookmarkedURL?.lastPathComponent
    }
    
    public func getCachedInfoSync(canFetch: Bool) -> FileInfo? {
        if cachedInfo == nil && canFetch {
            refreshInfoSync()
        }
        return cachedInfo
    }
    
    public func getInfoSync() -> FileInfo? {
        refreshInfoSync()
        return cachedInfo
    }
    
    private func refreshInfoSync() {
        let semaphore = DispatchSemaphore(value: 0)
        URLReference.backgroundQueue.async { [self] in
            self.refreshInfo { _ in
                semaphore.signal()
            }
        }
        semaphore.wait()
    }
    
    public func find(in refs: [URLReference], fallbackToNamesake: Bool=false) -> URLReference? {
        if let exactMatchIndex = refs.firstIndex(of: self) {
            return refs[exactMatchIndex]
        }
        
        if fallbackToNamesake {
            guard let fileName = self.url?.lastPathComponent else {
                return nil
            }
            return refs.first(where: { $0.url?.lastPathComponent == fileName })
        }
        return nil
    }
    
    
    fileprivate func processReference() {
        guard !data.isEmpty else {
            if location.isInternal {
                fileProvider = .localStorage
            }
            return
        }
        
        func getRecordValue(data: ByteArray, fpOffset: Int) -> String? {
            let contentBytes = data[fpOffset..<data.count]
            let contentStream = contentBytes.asInputStream()
            contentStream.open()
            defer { contentStream.close() }
            guard let recLength = contentStream.readUInt32(),
                let _ = contentStream.readUInt32(),
                let recBytes = contentStream.read(count: Int(recLength)),
                let utf8String = recBytes.toString(using: .utf8)
                else { return nil }
            return utf8String
        }
        
        func extractFileProviderID(_ fullString: String) -> String? {
            
            let regExpressions: [NSRegularExpression] = [
                try! NSRegularExpression(
                    pattern: #"fileprovider\:#?([a-zA-Z0-9\.\-\_]+)"#,
                    options: []),
                try! NSRegularExpression(
                    pattern: #"fp\:/.*?/([a-zA-Z0-9\.\-\_]+)/"#,
                    options: [])
            ]

            let fullRange = NSRange(fullString.startIndex..<fullString.endIndex, in: fullString)
            for regexp in regExpressions {
                if let match = regexp.firstMatch(in: fullString, options: [], range: fullRange),
                   let foundRange = Range(match.range(at: 1), in: fullString)
                {
                    return String(fullString[foundRange])
                }
            }
            return nil
        }
        
        func extractBookmarkedURLString(_ sandboxInfoString: String) -> String? {
            let infoTokens = sandboxInfoString.split(separator: ";")
            guard let lastToken = infoTokens.last else { return nil }
            return String(lastToken)
        }
        
        let data = ByteArray(data: self.data)
        guard data.count > 0 else { return }
        let stream = data.asInputStream()
        stream.open()
        defer { stream.close() }
        
        stream.skip(count: 12)
        guard let contentOffset32 = stream.readUInt32() else { return }
        let contentOffset = Int(contentOffset32)
        stream.skip(count: contentOffset - 12 - 4)
        guard let firstTOC32 = stream.readUInt32() else { return }
        stream.skip(count: Int(firstTOC32) - 4 + 4*4)
        
        var _fileProviderID: String?
        var _sandboxBookmarkedURLString: String?
        var _hackyBookmarkedURLString: String?
        var _volumePath: String?
        guard let recordCount = stream.readUInt32() else { return }
        for _ in 0..<recordCount {
            guard let recordID = stream.readUInt32(),
                let offset = stream.readUInt64()
                else { return }
            switch recordID {
            case 0x2002:
                _volumePath = getRecordValue(data: data, fpOffset: contentOffset + Int(offset))
            case 0x2070: 
                guard let fullFileProviderString =
                    getRecordValue(data: data, fpOffset: contentOffset + Int(offset))
                    else { continue }
                _fileProviderID = extractFileProviderID(fullFileProviderString)
            case 0xF080: 
                guard let sandboxInfoString =
                    getRecordValue(data: data, fpOffset: contentOffset + Int(offset))
                    else { continue }
                _sandboxBookmarkedURLString = extractBookmarkedURLString(sandboxInfoString)
            case 0x800003E8: 
                _hackyBookmarkedURLString =
                    getRecordValue(data: data, fpOffset: contentOffset + Int(offset))
            default:
                continue
            }
        }
        
        if let volumePath = _volumePath,
            let hackyURLString = _hackyBookmarkedURLString,
            !hackyURLString.starts(with: volumePath)
        {
            _hackyBookmarkedURLString = nil
        }
        if let urlString = _sandboxBookmarkedURLString ?? _hackyBookmarkedURLString {
            self.bookmarkedURL = URL(fileURLWithPath: urlString, isDirectory: false)
        }
        if let fileProviderID = _fileProviderID {
            self.fileProvider = FileProvider(rawValue: fileProviderID)
        } else {
            if ProcessInfo.isRunningOnMac {
                self.fileProvider = .localStorage
                return
            }
            assertionFailure()
            self.fileProvider = nil
        }
    }
}
