//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class VarDict: Eraseable {
    public static let version: UInt16 = 0x0100
    private static let versionMask: UInt16 = 0xFF00
    
    internal enum TypeID: UInt8 {
        case End     = 0x00 
        case Bool    = 0x08
        case UInt32  = 0x04
        case UInt64  = 0x05
        case Int32   = 0x0C
        case Int64   = 0x0D
        case String  = 0x18
        case ByteArray = 0x42
    }
    
    internal struct TypedValue: CustomStringConvertible, Eraseable {
        var type: TypeID
        var data: ByteArray 
        var count: Int { return data.count }
        
        public var description: String {
            switch type {
            case .End:
                return ""
            case .Bool:
                return (data[0] != 0) ? "true" : "false"
            case .UInt32, .Int32, .UInt64, .Int64:
                return data.asHexString
            case .String:
                return String(bytes: data.bytesCopy(), encoding: .utf8) ?? "(non UTF-8 string)"
            case .ByteArray:
                return "[\(data.count) bytes] " + data.asHexString
            }
        }
        
        init?(type: TypeID, rawData: ByteArray) {
            self.type = type
            switch type {
            case .End: return nil 
            case .Bool:
                guard rawData.count == 1 else { return nil }
                self.data = rawData
            case .UInt32, .Int32:
                guard rawData.count == 4 else { return nil }
                self.data = rawData
            case .UInt64, .Int64:
                guard rawData.count == 8 else { return nil }
                self.data = rawData
            case .String:
                self.data = rawData
            case .ByteArray:
                self.data = rawData
            }
        }
        
        private init(type: TypeID, data: ByteArray) {
            self.type = type
            self.data = data
        }
        init(value: Bool) {
            self.init(type: .Bool, data: ByteArray(bytes: [value ? 1 : 0]))
        }
        init(value: UInt32) {
            self.init(type: .UInt32, data: value.data)
        }
        init(value: Int32) {
            self.init(type: .Int32, data: value.data)
        }
        init(value: UInt64) {
            self.init(type: .UInt64, data: value.data)
        }
        init(value: Int64) {
            self.init(type: .Int64, data: value.data)
        }
        init(value: String) {
            let strData = ByteArray(utf8String: value)
            self.init(type: .String, data: strData)
        }
        init(value: ByteArray) {
            self.init(type: .ByteArray, data: value)
        }
        
        func erase() {
            data.erase()
        }
        
        func asBool() -> Bool? {
            guard type == .Bool else { return nil }
            return Bool(data[0] != 0)
        }
        func asUInt32() -> UInt32? {
            guard type == .UInt32 else { return nil }
            return UInt32(data: data)
        }
        func asInt32() -> Int32? {
            guard type == .Int32 else { return nil }
            return Int32(data: data)
        }
        func asUInt64() -> UInt64? {
            switch type {
            case .UInt64:
                return UInt64(data: data)
            case .UInt32:
                if let uint32 = asUInt32() {
                    return UInt64(exactly: uint32)
                }
            default: break
            }
            return nil
        }
        func asInt64() -> Int64? {
            switch type {
            case .Int64:
                return Int64(data: data)
            case .Int32:
                if let int32 = asInt32() {
                    return Int64(exactly: int32)
                }
            default: break
            }
            return nil
        }
        func asString() -> String? {
            guard type == .String else { return nil }
            return data.toString()
        }
        func asByteArray() -> ByteArray? {
            guard type == .ByteArray else { return nil }
            return data
        }
    }
    
    private var dict = [String: TypedValue]()
    private var orderedKeys = [String]() 
    
    public var isEmpty: Bool { return dict.isEmpty }
    
    public var data: ByteArray? {
        let stream = ByteArray.makeOutputStream()
        stream.open()
        defer { stream.close() }
        if write(to: stream) {
            return stream.data
        } else {
            return nil
        }
    }
    
    init() {
    }
    init?(data: ByteArray) {
        let readOK = read(data: data)
        if !readOK {
            return nil
        }
    }
    
    func read(data: ByteArray) -> Bool {
        let dataStream = data.asInputStream()
        dataStream.open()
        defer { dataStream.close() }
        return read(from: dataStream)
    }
    
    func read(from stream: ByteArray.InputStream) -> Bool {
        erase()
        guard let inVersion = stream.readUInt16() else { return false }
        guard (inVersion & VarDict.versionMask) == (VarDict.version & VarDict.versionMask) else {
            print("VarDict incompatible version: \(inVersion.asHexString)")
            return false
        }

        while true {
            guard let rawType = stream.readUInt8() else { return false }
            guard let type = TypeID(rawValue: rawType) else { return false }
            if type == .End {
                break;
            }
            guard let keyLen = stream.readInt32() else { return false  }
            guard let keyData = stream.read(count: Int(keyLen)) else { return false }
            guard let key = keyData.toString() else { return false }
            
            guard let valueLen = stream.readInt32() else { return false }
            guard let valueData = stream.read(count: Int(valueLen)) else { return false }
            guard let value = TypedValue(type: type, rawData: valueData) else { return false }
            setValue(key: key, value: value)
        }
        return true
    }
    
    func write(to stream: ByteArray.OutputStream) -> Bool {
        stream.write(value: VarDict.version)
        for key in orderedKeys {
            let typedValue = dict[key]! 
            stream.write(value: typedValue.type.rawValue)
            let keyData = ByteArray(utf8String: key)
            stream.write(value: Int32(keyData.count))
            stream.write(data: keyData)
            stream.write(value: Int32(typedValue.count))
            stream.write(data: typedValue.data)
        }
        stream.write(value: UInt8(0)) 
        return true
    }
    
    func setValue(key: String, value: TypedValue) {
        dict[key] = value
        if orderedKeys.contains(key) {
        } else {
            orderedKeys.append(key)
        }
    }
    func getValue(key: String) -> TypedValue? {
        return dict[key]
    }
    public func erase() {
        for (_, typedValue) in dict {
            typedValue.erase()
        }
        dict.removeAll()
        orderedKeys.removeAll()
    }
    
    internal func debugPrint() {
        for (key, typedValue) in dict {
            print("\(key) = \(typedValue)")
        }
    }
}
