//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final public class URLReference:
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
        case remote = 200

        public var isInternal: Bool {
            switch self {
            case .internalDocuments,
                 .internalBackup,
                 .internalInbox:
                return true
            case .external,
                 .remote:
                return false
            }
        }

        public var description: String {
            // swiftlint:disable line_length
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
            case .remote:
                return NSLocalizedString(
                    "[URLReference/Location/RemoteServer]",
                    bundle: Bundle.framework,
                    value: "Remote server",
                    comment: "Human-readable file location. Example: 'File Location: Remote server'")

            }
            // swiftlint:enable line_length
        }
    }

    public static let defaultTimeoutDuration: TimeInterval = 10.0

    public var visibleFileName: String { return url?.lastPathComponent ?? "?" }

    public private(set) var error: FileAccessError?
    public var hasError: Bool { return error != nil}

    public var needsReinstatement: Bool {
        guard let error else { return false }
        guard !location.isInternal else { return false }

        switch error {
        case FileAccessError.authorizationRequired(_, _):
            return true
        default:
            break
        }

        guard let nsError = error.underlyingError as NSError? else {
            return false
        }
        switch (nsError.domain, nsError.code) {
        #if !targetEnvironment(macCatalyst)
        case (NSFileProviderErrorDomain, NSFileProviderError.noSuchItem.rawValue):
            return true
        #endif
        default:
            return false
        }
    }

    private let data: Data

    private lazy var dataSHA256: ByteArray = {
        return ByteArray(data: data).sha256
    }()

    public let location: Location

    internal var bookmarkedURL: URL?
    internal var cachedURL: URL?
    internal var resolvedURL: URL?

    internal var originalURL: URL? {
        return bookmarkedURL ?? cachedURL
    }

    public var url: URL? {
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
    private let resolveQueue = DispatchQueue(
        label: "com.keepassium.URLReference.resolve",
        attributes: [], 
        target: URLReference.backgroundQueue
    )

    private enum CodingKeys: String, CodingKey {
        case data = "data"
        case location = "location"
        case cachedURL = "url"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(Data.self, forKey: .data)
        location = try container.decode(Location.self, forKey: .location)
        cachedURL = try container.decode(URL.self, forKey: .cachedURL)
        self.processReference()
    }

    internal init(from url: URL, location: Location, allowOptimization: Bool = true) throws {
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        cachedURL = url
        bookmarkedURL = url
        if URLReference.shouldMakeBookmark(
            url: url,
            location: location,
            allowOptimization: allowOptimization
        ) {
            data = try URLReference.makeBookmarkData(for: url, location: location) 
        } else {
            data = Data() 
        }
        self.location = location
        processReference()
    }

    private static func shouldMakeBookmark(url: URL, location: Location, allowOptimization: Bool) -> Bool {
        guard url.scheme == "file" else {
            return false 
        }
        guard allowOptimization else {
            return true
        }
        return !location.isInternal
    }

    private static func makeBookmarkData(for url: URL, location: Location) throws -> Data {
        let options: URL.BookmarkCreationOptions
        if ProcessInfo.isRunningOnMac {
            options = []
        } else {
            options = [.minimalBookmark]
        }

        let result: Data
        if FileKeeper.platformSupportsSharedReferences {
            result = try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil) 
        } else {
            if location.isInternal {
                result = Data() 
            } else {
                result = try url.bookmarkData(
                    options: options,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil) 
            }
        }
        return result
    }

    public static func == (lhs: URLReference, rhs: URLReference) -> Bool {
        guard lhs.location == rhs.location else { return false }
        guard let lhsOriginalURL = lhs.originalURL, let rhsOriginalURL = rhs.originalURL else {
            assertionFailure()
            Diag.debug("Original URL of the file is nil.")
            return false
        }
        guard lhsOriginalURL == rhsOriginalURL else {
            return false
        }
        let lhsDataHash = lhs.dataSHA256
        let rhsDataHash = rhs.dataSHA256
        return lhsDataHash == rhsDataHash
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
        return try? JSONDecoder().decode(URLReference.self, from: data)
    }

    public var debugDescription: String {
        return " ‣ Location: \(location)\n" +
            " ‣ bookmarkedURL: \(bookmarkedURL?.relativeString ?? "nil")\n" +
            " ‣ cachedURL: \(cachedURL?.relativeString ?? "nil")\n" +
            " ‣ resolvedURL: \(resolvedURL?.relativeString ?? "nil")\n" +
            " ‣ fileProvider: \(fileProvider?.id ?? "nil")\n" +
            " ‣ data: \(data.count) bytes"
    }


    public typealias CreateCallback = (Result<URLReference, FileAccessError>) -> Void

    public static func create(
        for url: URL,
        location: URLReference.Location,
        allowOptimization: Bool = true,
        completion: @escaping CreateCallback
    ) {
        let completionQueue = OperationQueue.main
        guard URLReference.shouldMakeBookmark(url: url, location: location, allowOptimization: allowOptimization) else {
            do {
                let fileRef = try URLReference(
                    from: url,
                    location: location,
                    allowOptimization: allowOptimization
                )
                completionQueue.addOperation {
                    completion(.success(fileRef))
                }
            } catch {
                Diag.error("Failed to create file reference [message: \(error.localizedDescription)]")
                let fileAccessError = FileAccessError.make(
                    from: error,
                    fileName: url.lastPathComponent,
                    fileProvider: nil)
                completionQueue.addOperation {
                    completion(.failure(fileAccessError))
                }
            }
            return
        }

        FileDataProvider.bookmarkFile(
            at: url,
            location: location,
            creationHandler: { _url, _location throws -> URLReference in
                return try URLReference(from: _url, location: _location, allowOptimization: allowOptimization)
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }


    public typealias ResolveCallback = (Result<URL, FileAccessError>) -> Void

    public func resolveAsync(
        timeout: Timeout,
        callbackQueue: OperationQueue = .main,
        callback: @escaping ResolveCallback
    ) {
        guard !data.isEmpty else {
            callbackQueue.addOperation { [self] in
                if let originalURL = originalURL {
                    callback(.success(originalURL))
                } else {
                    Diag.error("Both reference data and original URL are empty")
                    callback(.failure(.internalError))
                }
            }
            return
        }

        let fileProvider = self.fileProvider
        URLReference.backgroundQueue.async {
            let resolver = DispatchWorkItem {
                do {
                    let url = try self.resolveSync()
                    self.error = nil
                    callbackQueue.addOperation {
                        callback(.success(url))
                    }
                } catch {
                    let fileAccessError = FileAccessError.make(
                        from: error,
                        fileName: self.visibleFileName,
                        fileProvider: fileProvider
                    )
                    self.error = fileAccessError
                    callbackQueue.addOperation {
                        callback(.failure(fileAccessError))
                    }
                }
            }
            self.resolveQueue.async(execute: resolver)
            switch resolver.wait(timeout: timeout.deadline) {
            case .success:
                break
            case .timedOut:
                resolver.cancel() 
                let fileAccessError = FileAccessError.timeout(fileProvider: fileProvider)
                self.error = fileAccessError
                callbackQueue.addOperation {
                    callback(.failure(fileAccessError))
                }
            }
        }
    }


    public typealias InfoCallback = (Result<FileInfo, FileAccessError>) -> Void

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

    public func getCachedInfo(
        canFetch: Bool,
        timeout: Timeout = Timeout(duration: URLReference.defaultTimeoutDuration),
        completion callback: @escaping InfoCallback
    ) {
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
            refreshInfo(timeout: timeout, completion: callback)
        }
    }

    public func refreshInfo(
        timeout: Timeout = Timeout(duration: URLReference.defaultTimeoutDuration),
        completionQueue: OperationQueue = .main,
        completion: @escaping InfoCallback
    ) {
        registerInfoRefreshRequest(.added)
        resolveAsync(timeout: timeout, callbackQueue: completionQueue) { [weak self] result in
            guard let self = self else { return }

            assert(completionQueue.isCurrent)
            switch result {
            case .success(let url):
                self.refreshInfo(
                    for: url,
                    fileProvider: self.fileProvider,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let fileAccessError):
                self.registerInfoRefreshRequest(.completed)
                self.error = fileAccessError
                completion(.failure(fileAccessError))
            }
        }
    }

    private func refreshInfo(
        for url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping InfoCallback
    ) {
        FileDataProvider.readFileInfo(
            at: url,
            fileProvider: fileProvider,
            canUseCache: false,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: { [weak self] result in
                guard let self = self else { return }
                self.registerInfoRefreshRequest(.completed)
                switch result {
                case .success(let fileInfo):
                    self.cachedInfo = fileInfo
                    self.error = nil
                case .failure(let fileAccessError):
                    self.error = fileAccessError
                }
                completion(result)
            }
        )
    }


    public func resolveSync() throws -> URL {
        guard data.count > 0 else {
            return resolvedURL ?? cachedURL ?? bookmarkedURL! 
        }
        if FileKeeper.platformSupportsSharedReferences {
        } else {
            if location.isInternal, let cachedURL = self.cachedURL {
                return cachedURL
            }
        }

        if Settings.current.isNetworkAccessAllowed,
           let originalURL = originalURL,
           originalURL.isRemoteURL
        {
            self.resolvedURL = originalURL
            return originalURL
        }

        var isStale = false
        let _resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        self.resolvedURL = _resolvedURL
        return _resolvedURL
    }

    public func getDescriptor() -> Descriptor? {
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
        resolveQueue.async { [self] in
            self.refreshInfo { _ in
                semaphore.signal()
            }
        }
        semaphore.wait()
    }

    public func find(in refs: [URLReference], fallbackToNamesake: Bool = false) -> URLReference? {
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
            fileProvider = detectFileProvider(hint: nil)
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

            // swiftlint:disable line_length
            let regExpressions: [NSRegularExpression] = [
                try! NSRegularExpression(
                    pattern: #"fileprovider\:#?([a-zA-Z0-9\.\-\_]+)"#,
                    options: []),
                try! NSRegularExpression(
                    pattern: #"fp\:/.*?/([a-zA-Z0-9\.\-\_]+)/"#,
                    options: [])
            ]
            // swiftlint:enable line_length

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
        stream.skip(count: Int(firstTOC32) - 4 + 4 * 4)

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
        self.fileProvider = detectFileProvider(hint: _fileProviderID)
    }

    private func detectFileProvider(hint: String?) -> FileProvider? {
        if let fileProviderID = hint {
            return FileProvider(rawValue: fileProviderID)
        }

        if let url = url,
           let fileProviderDedicatedToSuchURLs = DataSourceFactory.findInAppFileProvider(for: url)
        {
            return fileProviderDedicatedToSuchURLs
        }

        if location.isInternal || ProcessInfo.isRunningOnMac {
            return .localStorage
        }
        if FileKeeper.platformSupportsSharedReferences {
            return .localStorage
        } else {
            assertionFailure()
            return nil
        }
    }
}
