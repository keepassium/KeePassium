//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class ByteArray: Eraseable, Cloneable, Codable, CustomDebugStringConvertible {

    public class InputStream {
        fileprivate let base: Foundation.InputStream
        var hasBytesAvailable: Bool { return base.hasBytesAvailable }
        
        fileprivate init(data: Data) {
            base = Foundation.InputStream(data: data)
        }
        
        func open() {
            base.open()
        }
        func close() {
            base.close()
        }
        
        func read(count: Int) -> ByteArray? {
            var out = [UInt8].init(repeating: 0, count: count)

            var bytesRead = 0
            while bytesRead < count {
                let remainingCount = count - bytesRead
                let n = out.withUnsafeMutableBufferPointer {
                    (bytes: inout UnsafeMutableBufferPointer<UInt8>) in
                    return base.read(bytes.baseAddress! + bytesRead, maxLength: remainingCount)
                }
                guard n > 0 else {
                    print("Stream reading problem")
                    return nil
                }
                bytesRead += n
            }
            return ByteArray(bytes: out)
        }
        
        @discardableResult
        func skip(count: Int) -> Int {
            let dataRead = read(count: count)
            return dataRead?.count ?? 0
        }
        func readUInt8() -> UInt8? {
            let data = self.read(count: MemoryLayout<UInt8>.size)
            return UInt8(data: data)
        }
        func readUInt16() -> UInt16? {
            let data = self.read(count: MemoryLayout<UInt16>.size)
            return UInt16(data: data)
        }
        func readUInt32() -> UInt32? {
            let data = self.read(count: MemoryLayout<UInt32>.size)
            return UInt32(data: data)
        }
        func readUInt64() -> UInt64? {
            let data = self.read(count: MemoryLayout<UInt64>.size)
            return UInt64(data: data)
        }
        func readInt8() -> Int8? {
            let data = self.read(count: MemoryLayout<Int8>.size)
            return Int8(data: data)
        }
        func readInt16() -> Int16? {
            let data = self.read(count: MemoryLayout<Int16>.size)
            return Int16(data: data)
        }
        func readInt32() -> Int32? {
            let data = self.read(count: MemoryLayout<Int32>.size)
            return Int32(data: data)
        }
        func readInt64() -> Int64? {
            let data = self.read(count: MemoryLayout<Int64>.size)
            return Int64(data: data)
        }
    }
    public class OutputStream {
        private let base: Foundation.OutputStream
        fileprivate init() {
            base = Foundation.OutputStream(toMemory: ())
        }
        public func open() {
            base.open()
        }
        public func close() {
            base.close()
        }
        var data: ByteArray? {
            if let data = base.property(forKey: .dataWrittenToMemoryStreamKey) as? Data {
                return ByteArray(data: data)
            } else {
                return nil
            }
        }

        @discardableResult
        func write<T: FixedWidthInteger>(value: T) -> Int {
            return write(data: value.data)
        }
        @discardableResult
        func write(data: ByteArray) -> Int {
            guard data.count > 0 else { return 0 } 
            
            let writtenCount = data.withBytes { bytes in
                return base.write(bytes, maxLength: bytes.count)
            }
            assert(writtenCount == data.count, "Written \(writtenCount) bytes instead of \(data.count) requested")
            return writtenCount
        }
    }
    
    private enum CodingKeys: CodingKey {
        case bytes
    }
    
    fileprivate var bytes: [UInt8]
    fileprivate var sha256cache: ByteArray?
    fileprivate var sha512cache: ByteArray?

    public var isEmpty: Bool { return bytes.isEmpty }
    public var count: Int { return bytes.count }
    
    public var sha256: ByteArray {
        if sha256cache == nil {
            sha256cache = ByteArray(bytes: CryptoManager.sha256(of: bytes))
        }
        return sha256cache! 
    }
    
    public var sha512: ByteArray {
        if sha512cache == nil {
            sha512cache = ByteArray(bytes: CryptoManager.sha512(of: bytes))
        }
        return sha512cache! 
    }
    
    public var asData: Data { return Data(self.bytes) }
    
    subscript (index: Int) -> UInt8 {
        get { return bytes[index] }
        set { bytes[index] = newValue }
    }
    subscript (range: CountableRange<Int>) -> ByteArray {
        return ByteArray(bytes: self.bytes[range])
    }

    public var debugDescription: String {
        return asHexString
    }
    
    public init() {
        bytes = []
    }
    public init(data: Data) {
        self.bytes = Array(data)
    }
    public init(bytes: [UInt8]) {
        self.bytes = [UInt8](bytes)
    }
    public init(bytes: ArraySlice<UInt8>) {
        self.bytes = [UInt8](bytes)
    }
    
    convenience public init(count: Int) {
        self.init(bytes: [UInt8](repeating: 0, count: count))
    }
    convenience public init(capacity: Int) {
        self.init()
        bytes.reserveCapacity(capacity)
    }
    convenience public init(contentsOf url: URL, options: Data.ReadingOptions = []) throws {
        let data = try Data(contentsOf: url, options: options)
        self.init(data: data)
    }
    convenience public init(utf8String: String) {
        self.init(data: utf8String.data(using: .utf8)!) 
    }
    convenience public init?(base64Encoded: String?) {
        if let base64Encoded = base64Encoded {
            guard let data = Data(base64Encoded: base64Encoded) else { return nil }
            self.init(data: data)
        } else {
            return nil
        }
    }
    
    convenience public init?<T: StringProtocol>(hexString string: T) {
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }
        
        self.init()
        bytes.reserveCapacity(string.utf16.count/2)
        var even = true
        var byte: UInt8 = 0
        for c in string.utf16 {
            guard let val = decodeNibble(u: c) else { return nil }
            if even {
                byte = val << 4
            } else {
                byte += val
                bytes.append(byte)
            }
            even = !even
        }
        guard even else { return nil }
    }
    
    deinit {
        erase()
    }
    
    fileprivate func invalidateHashCache() {
        sha256cache = nil
        sha512cache = nil
    }
    
    public func clone() -> ByteArray {
        let bytesClone = self.bytes.clone()
        return ByteArray(bytes: bytesClone)
    }
    
    public func bytesCopy() -> [UInt8] {
        return bytes.clone()
    }
    
    public func erase() {
        bytes.erase()
        invalidateHashCache()
    }
    
    public var asHexString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self.bytes {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
    
    public func prefix(_ maxLength: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.prefix(maxLength))
    }
    public func prefix(upTo: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.prefix(upTo: upTo))
    }
    public func suffix(from: Int) -> ByteArray {
        return ByteArray(bytes: self.bytes.suffix(from: from))
    }
    
    public func trim(toCount newCount: Int) {
        if (newCount < 0) || (bytes.count <= newCount) { return }
        
        for i in newCount..<bytes.count {
            bytes[i] = 0
        }
        bytes.removeLast(bytes.count - newCount)
        invalidateHashCache()
    }
    
    public static func concat(_ arrays: ByteArray...) -> ByteArray {
        var totalSize = 0
        for arr in arrays {
            totalSize += arr.count
        }
        var buffer = [UInt8]()
        buffer.reserveCapacity(totalSize)
        for arr in arrays {
            buffer.append(contentsOf: arr.bytes)
        }
        return ByteArray(bytes: buffer)
    }
    
    public func append(_ value: UInt8) {
        bytes.append(value)
        invalidateHashCache()
    }
    public func append(bytes: Array<UInt8>) {
        self.bytes.append(contentsOf: bytes)
        invalidateHashCache()
    }
    public func append(_ another: ByteArray) {
        self.bytes.append(contentsOf: another.bytes)
        invalidateHashCache()
    }
    
    public func write(to url: URL, options: Data.WritingOptions) throws {
        try asData.write(to: url, options: options)
    }
    
    @discardableResult
    public func withBytes<TResult>(_ body: ([UInt8]) -> TResult) -> TResult {
        return body(bytes)
    }
    @discardableResult
    public func withMutableBytes<TResult>(_ body: (inout [UInt8]) -> TResult) -> TResult {
        return body(&bytes)
    }

    
    public func base64EncodedString() -> String {
        return Data(bytes).base64EncodedString()
    }
    
    public func toString(using encoding: String.Encoding = .utf8) -> String? {
        return String(bytes: self.bytes, encoding: encoding)
    }
    
    public func asInputStream() -> ByteArray.InputStream {
        return ByteArray.InputStream(data: Data(self.bytes))
    }
    public static func makeOutputStream() -> ByteArray.OutputStream {
        return ByteArray.OutputStream()
    }
    
    public func gunzipped() throws -> ByteArray {
        return try ByteArray(data: Data(self.bytes).gunzipped())
    }

    public func gzipped() throws -> ByteArray {
        return try ByteArray(data: Data(self.bytes).gzipped(level: .bestCompression))
    }
    
    public func containsOnly(_ value: UInt8) -> Bool {
        for i in 0..<bytes.count {
            if bytes[i] != value {
                return false
            }
        }
        return true
    }
}

extension ByteArray: Equatable {
    public static func ==(lhs: ByteArray, rhs: ByteArray) -> Bool {
        return lhs.bytes == rhs.bytes
    }
}

extension ByteArray: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
    }
}


public final class SecureBytes: Eraseable, Cloneable, Codable {
    
    fileprivate var bytes: [UInt8]
    
    private var key: SecKey?
    
    public var count: Int {
        if bytes.isEmpty {
            return 0
        } else {
            return withDecryptedBytes { $0.count }
        }
    }
    
    public var isEmpty: Bool {
        return bytes.isEmpty
    }
    
    public var isEncrypted: Bool {
        return key != nil
    }

    public var sha256: SecureBytes {
        let hashBytes = withDecryptedBytes { plainTextBytes in
            return CryptoManager.sha256(of: plainTextBytes)
        }
        return SecureBytes.from(hashBytes)
    }

    public var sha512: SecureBytes {
        let hashBytes = withDecryptedBytes { plainTextBytes in
            return CryptoManager.sha512(of: plainTextBytes)
        }
        return SecureBytes.from(hashBytes)
    }
    
    private init(_ bytes: [UInt8], key: SecKey?) {
        self.key = key
        self.bytes = bytes.withUnsafeBufferPointer { [UInt8]($0) } 
        _ = self.bytes.withUnsafeBufferPointer { ptr in
            mlock(ptr.baseAddress, ptr.count)
        }
    }
    
    deinit {
        erase()
        bytes.withUnsafeBufferPointer { (ptr) -> Void in
            munlock(ptr.baseAddress, ptr.count)
        }
    }
    
    public func erase() {
        key = nil
        bytes.erase()
    }

    
    private enum CodingKeys: String, CodingKey {
        case format
        case bytes
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let format = try container.decodeIfPresent(Int.self, forKey: .format) ?? 0
        switch format {
        case 0:
            var plainTextBytes = try container.decode([UInt8].self, forKey: .bytes)
            defer {
                plainTextBytes.erase()
            }
            var key = Keychain.shared.getMemoryProtectionKey()
            let bytes = SecureBytes.encrypt(plainTextBytes, with: &key)
            self.init(bytes, key: key)
        case 1:
            guard let key = Keychain.shared.getMemoryProtectionKey() else {
                SecureBytes.__encryption_key_is_missing()
                fatalError()
            }
            let encryptedBytes = try container.decode([UInt8].self, forKey: .bytes)
            self.init(encryptedBytes, key: key)
        default:
            SecureBytes.__unexpected_serialization_format(format)
            fatalError()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if key == nil {
            try container.encode(bytes, forKey: .bytes)
        } else {
            let format: Int = 1
            try container.encode(format, forKey: .format)
            try container.encode(bytes, forKey: .bytes)
        }
    }
        
    
    public static func empty() -> SecureBytes {
        return SecureBytes([], key: nil)
    }
    
    public static func from(_ bytes: [UInt8], encrypt: Bool = true) -> SecureBytes {
        if bytes.isEmpty {
            return SecureBytes.empty()
        }
        if encrypt {
            var key = Keychain.shared.getMemoryProtectionKey()
            let encrypted = SecureBytes.encrypt(bytes, with: &key)
            return SecureBytes(encrypted, key: key)
        } else {
            return SecureBytes(bytes.clone(), key: nil)
        }
    }
    
    public static func from(_ bytes: ArraySlice<UInt8>, encrypt: Bool = true) -> SecureBytes {
        return from(Array(bytes), encrypt: encrypt)
    }

    public static func from(_ byteArray: ByteArray, encrypt: Bool = true) -> SecureBytes {
        return from(byteArray.bytes, encrypt: encrypt)
    }
    
    public static func from(_ data: Data, encrypt: Bool = true) -> SecureBytes {
        return from(Array(data), encrypt: encrypt)
    }
    
    
    public func decrypted() -> SecureBytes {
        return withDecryptedBytes {
            SecureBytes.from($0.clone(), encrypt: false)
        }
    }

    @discardableResult
    public func withDecryptedBytes<T>(_ handler: ([UInt8]) throws -> T) rethrows -> T {
        if bytes.isEmpty {
            return try handler([])
        }
        
        assert(!bytes.allSatisfy { $0 == 0 }, "All bytes are zero. Possibly erased too early?")
        
        guard let key = key else {
            var bytesCopy = bytes.clone()
            defer {
                bytesCopy.erase()
            }
            return try handler(bytesCopy)
        }
        
        let decryptedBytes = SecureBytes.decrypt(bytes, with: key)
        let result = try decryptedBytes.withUnsafeBytes { pointer -> T in
            let mutablePointer = UnsafeMutableRawPointer(mutating: pointer.baseAddress!)
            mlock(mutablePointer, pointer.count)
            defer {
                memset_s(mutablePointer, pointer.count, 0, pointer.count)
                munlock(mutablePointer, pointer.count)
            }
            return try handler(decryptedBytes)
        }
        return result
    }
    
    @discardableResult
    public func withDecryptedMutableBytes<T>(_ handler: (inout [UInt8]) throws -> T) rethrows -> T {
        return try withDecryptedBytes {
            var copy = isEncrypted ? $0 : $0.clone()
            defer {
                copy.erase()
            }
            return try handler(&copy)
        }
    }
    
    @discardableResult
    public func withDecryptedByteArray<T>(_ handler: (ByteArray) -> T) -> T {
        return withDecryptedBytes {
            let byteArray = ByteArray(bytes: $0)
            return handler(byteArray)
        }
    }
    
    @discardableResult
    public func withDecryptedData<T>(_ handler: (Data) throws -> T) rethrows -> T {
        return try withDecryptedBytes { bytes -> T in
            let count = bytes.count
            return try bytes.withUnsafeBytes { bytesPtr -> T in
                let mutablePtr = UnsafeMutableRawPointer(mutating: bytesPtr.baseAddress!)
                let data = Data(
                    bytesNoCopy: mutablePtr, // "no copy" is just a hint, not a guarantee
                    count: count,
                    deallocator: .none 
                )
                return try handler(data)
            }
        }
    }
    
    public func clone() -> SecureBytes {
        let bytesCopy = bytes.clone()
        return SecureBytes(bytesCopy, key: key)
    }
    
    public static func concat(_ parts: SecureBytes...) -> SecureBytes {
        var plainTexts = [ByteArray]()
        var concatenatedPlainTexts = [UInt8]()
        defer {
            plainTexts.erase()
            concatenatedPlainTexts.erase()
        }
        
        var hasEncryptedInput = false
        var totalSize = 0
        parts.forEach { part in
            hasEncryptedInput = hasEncryptedInput || part.isEncrypted
            part.withDecryptedByteArray { decryptedBytes in
                plainTexts.append(decryptedBytes.clone())
                totalSize += decryptedBytes.count
            }
        }
        concatenatedPlainTexts.reserveCapacity(totalSize)
        plainTexts.forEach {
            concatenatedPlainTexts.append(contentsOf: $0.bytes)
        }
        return SecureBytes.from(concatenatedPlainTexts, encrypt: hasEncryptedInput)
    }
    
    public func interpretedAsASCIIHexString() -> SecureBytes? {
        guard let hexString = withDecryptedBytes({ String(bytes: $0, encoding: .ascii) }),
              let byteArray = ByteArray(hexString: hexString)
        else {
            return nil
        }
        return SecureBytes.from(byteArray)
    }
    
    
    private static let algorithm = SecKeyAlgorithm.eciesEncryptionCofactorVariableIVX963SHA256AESGCM
    
    private static func encrypt(_ plainText: [UInt8], with key: inout SecKey?) -> [UInt8] {
        guard plainText.count > 0 else {
            return []
        }
        guard let privateKey = key else {
            Diag.warning("Cannot encrypt, there is no key")
            return Array(plainText)
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            Diag.warning("Cannot encrypt, no public key")
            key = nil
            return Array(plainText)
        }
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt, SecureBytes.algorithm) else {
            Diag.warning("Cannot encrypt, algorithm is not supported")
            key = nil
            return Array(plainText)
        }
        
        var error: Unmanaged<CFError>?
        
        let plainTextData = Data(bytes: plainText, count: plainText.count) as CFData
        let outData = SecKeyCreateEncryptedData(publicKey, algorithm, plainTextData, &error) as Data?
        guard let outData = outData else {
            let err = error!.takeRetainedValue() as Error
            Diag.warning("Cannot encrypt [message: \(err.localizedDescription)]")
            key = nil
            return Array(plainText)
        }
        return outData.bytes
    }
    
    private static func decrypt(_ encrypted: [UInt8], with key: SecKey?) -> [UInt8] {
        guard encrypted.count > 0 else {
            return []
        }
        guard let key = key else {
            return Array(encrypted)
        }
        
        guard SecKeyIsAlgorithmSupported(key, .decrypt, SecureBytes.algorithm) else {
            __decryption_algorithm_is_not_supported()
            fatalError()
        }
        
        var error: Unmanaged<CFError>?
        let plainTextData = SecKeyCreateDecryptedData(
            key,
            SecureBytes.algorithm,
            Data(bytes: encrypted, count: encrypted.count) as CFData,
            &error
        ) as Data?
        guard let plainTextData = plainTextData else {
            let err = error!.takeRetainedValue() as Error
            let nsError = err as NSError
            let message = "\(err.localizedDescription): \(nsError.userInfo)"
            if encrypted.allSatisfy({ $0 == 0 }) {
                __decryption_failed_input_is_zeros(code: nsError.code, message: message)
            } else {
                __decryption_failed(code: nsError.code, message: message)
            }
            fatalError() 
        }
        return plainTextData.bytes
    }
}

extension SecureBytes {
    @inline(never)
    private static func __unexpected_serialization_format(_ format: Int) {
        fatalError("Unexpected serialization format: \(format)")
    }
    
    @inline(never)
    private static func __encryption_key_is_missing() {
        fatalError("Got encrypted SecureBytes, but no key. Something is very wrong.")
    }
    
    @inline(never)
    private static func __decryption_algorithm_is_not_supported() {
        fatalError("Decryption algorithm is not supported. Something is very wrong.")
    }

    /* There are decryption failures occasionally, so we need to know the error code.
       To do so, we call either *_bit_0 and *_bit_1 for each bit of the error code,
       so that the stack trace includes the error code in binary format.
    */

    @inline(never)
    private static func __decryption_failed_input_is_zeros(code: Int, message: String) {
        guard code >= 0 else {
            __decryption_failed_error_code_negative(code: code)
            return
        }
        if code % 2 == 0 {
            __decryption_failed_error_code_bit_0(code >> 1)
        } else {
            __decryption_failed_error_code_bit_1(code >> 1)
        }
    }

    @inline(never)
    private static func __decryption_failed(code: Int, message: String) {
        guard code >= 0 else {
            __decryption_failed_error_code_negative(code: code)
            return
        }
        if code % 2 == 0 {
            __decryption_failed_error_code_bit_0(code >> 1)
        } else {
            __decryption_failed_error_code_bit_1(code >> 1)
        }
    }
    
    @inline(never)
    private static func __decryption_failed_error_code_negative(code: Int) {
        let code = abs(code) 
        if code % 2 == 0 {
            __decryption_failed_error_code_bit_0(code >> 1)
        } else {
            __decryption_failed_error_code_bit_1(code >> 1)
        }
    }

    @inline(never)
    private static func __decryption_failed_error_code_bit_0(_ remainder: Int) {
        guard remainder != 0 else {
            fatalError("Decryption failed, error code in stack trace")
        }
        if remainder % 2 == 0 {
            __decryption_failed_error_code_bit_0(remainder >> 1)
        } else {
            __decryption_failed_error_code_bit_1(remainder >> 1)
        }
    }
    
    @inline(never)
    private static func __decryption_failed_error_code_bit_1(_ remainder: Int) {
        guard remainder != 0 else {
            fatalError("Decryption failed, error code in stack trace")
        }
        if remainder % 2 == 0 {
            __decryption_failed_error_code_bit_0(remainder >> 1)
        } else {
            __decryption_failed_error_code_bit_1(remainder >> 1)
        }
    }
}

#if DEBUG
extension SecureBytes: CustomStringConvertible {
    public var description: String {
        return ByteArray(bytes: bytes.clone()).asHexString
    }
}
#endif
