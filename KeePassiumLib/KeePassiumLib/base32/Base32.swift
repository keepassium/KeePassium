//
//  Base32.swift
//  TOTP
//
//  Created by 野村 憲男 on 1/24/15.
//
//  Copyright (c) 2015 Norio Nomura
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

// https://tools.ietf.org/html/rfc4648

// MARK: - Base32 Data <-> String

public func base32Encode(_ data: Data) -> String {
    return data.withUnsafeBytes {
        base32encode($0.baseAddress!, $0.count, alphabetEncodeTable)
    }
}

public func base32HexEncode(_ data: Data) -> String {
    return data.withUnsafeBytes {
        base32encode($0.baseAddress!, $0.count, extendedHexAlphabetEncodeTable)
    }
}

public func base32DecodeToData(_ string: String) -> Data? {
    return base32decode(string, alphabetDecodeTable).flatMap {
        $0.withUnsafeBufferPointer {
            Data(bytes: $0.baseAddress!, count: $0.count)
        }
    }
}

public func base32HexDecodeToData(_ string: String) -> Data? {
    return base32decode(string, extendedHexAlphabetDecodeTable).flatMap {
        $0.withUnsafeBufferPointer {
            Data(bytes: $0.baseAddress!, count: $0.count)
        }
    }
}

// MARK: - Base32 [UInt8] <-> String

public func base32Encode(_ array: [UInt8]) -> String {
    return base32encode(array, array.count, alphabetEncodeTable)
}

public func base32HexEncode(_ array: [UInt8]) -> String {
    return base32encode(array, array.count, extendedHexAlphabetEncodeTable)
}

public func base32Decode(_ string: String) -> [UInt8]? {
    return base32decode(string, alphabetDecodeTable)
}

public func base32HexDecode(_ string: String) -> [UInt8]? {
    return base32decode(string, extendedHexAlphabetDecodeTable)
}

// MARK: extensions

extension String {
    // base32
    public var base32DecodedData: Data? {
        return base32DecodeToData(self)
    }
    
    public var base32EncodedString: String {
        return utf8CString.withUnsafeBufferPointer {
            base32encode($0.baseAddress!, $0.count - 1, alphabetEncodeTable)
        }
    }
    
    public func base32DecodedString(_ encoding: String.Encoding = .utf8) -> String? {
        return base32DecodedData.flatMap {
            String(data: $0, encoding: .utf8)
        }
    }

    // base32Hex
    public var base32HexDecodedData: Data? {
        return base32HexDecodeToData(self)
    }
    
    public var base32HexEncodedString: String {
        return utf8CString.withUnsafeBufferPointer {
            base32encode($0.baseAddress!, $0.count - 1, extendedHexAlphabetEncodeTable)
        }
    }
    
    public func base32HexDecodedString(_ encoding: String.Encoding = .utf8) -> String? {
        return base32HexDecodedData.flatMap {
            String(data: $0, encoding: .utf8)
        }
    }
}

extension Data {
    // base32
    public var base32EncodedString: String {
        return base32Encode(self)
    }
    
    public var base32EncodedData: Data {
        return base32EncodedString.dataUsingUTF8StringEncoding
    }
    
    public var base32DecodedData: Data? {
        return String(data: self, encoding: .utf8).flatMap(base32DecodeToData)
    }

    // base32Hex
    public var base32HexEncodedString: String {
        return base32HexEncode(self)
    }
    
    public var base32HexEncodedData: Data {
        return base32HexEncodedString.dataUsingUTF8StringEncoding
    }
    
    public var base32HexDecodedData: Data? {
        return String(data: self, encoding: .utf8).flatMap(base32HexDecodeToData)
    }
}

// MARK: - private

// MARK: encode

let alphabetEncodeTable: [Int8] = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","2","3","4","5","6","7"].map { (c: UnicodeScalar) -> Int8 in Int8(c.value) }

let extendedHexAlphabetEncodeTable: [Int8] = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V"].map { (c: UnicodeScalar) -> Int8 in Int8(c.value) }

private func base32encode(_ data: UnsafeRawPointer, _ length: Int, _ table: [Int8]) -> String {
    if length == 0 {
        return ""
    }
    var length = length
    
    var bytes = data.assumingMemoryBound(to: UInt8.self)
    
    let resultBufferSize = Int(ceil(Double(length) / 5)) * 8 + 1    // need null termination
    let resultBuffer = UnsafeMutablePointer<Int8>.allocate(capacity: resultBufferSize)
    var encoded = resultBuffer
    
    // encode regular blocks
    while length >= 5 {
        encoded[0] = table[Int(bytes[0] >> 3)]
        encoded[1] = table[Int((bytes[0] & 0b00000111) << 2 | bytes[1] >> 6)]
        encoded[2] = table[Int((bytes[1] & 0b00111110) >> 1)]
        encoded[3] = table[Int((bytes[1] & 0b00000001) << 4 | bytes[2] >> 4)]
        encoded[4] = table[Int((bytes[2] & 0b00001111) << 1 | bytes[3] >> 7)]
        encoded[5] = table[Int((bytes[3] & 0b01111100) >> 2)]
        encoded[6] = table[Int((bytes[3] & 0b00000011) << 3 | bytes[4] >> 5)]
        encoded[7] = table[Int((bytes[4] & 0b00011111))]
        length -= 5
        encoded = encoded.advanced(by: 8)
        bytes = bytes.advanced(by: 5)
    }
    
    // encode last block
    var byte0, byte1, byte2, byte3, byte4: UInt8
    (byte0, byte1, byte2, byte3, byte4) = (0,0,0,0,0)
    switch length {
    case 4:
        byte3 = bytes[3]
        encoded[6] = table[Int((byte3 & 0b00000011) << 3 | byte4 >> 5)]
        encoded[5] = table[Int((byte3 & 0b01111100) >> 2)]
        fallthrough
    case 3:
        byte2 = bytes[2]
        encoded[4] = table[Int((byte2 & 0b00001111) << 1 | byte3 >> 7)]
        fallthrough
    case 2:
        byte1 = bytes[1]
        encoded[3] = table[Int((byte1 & 0b00000001) << 4 | byte2 >> 4)]
        encoded[2] = table[Int((byte1 & 0b00111110) >> 1)]
        fallthrough
    case 1:
        byte0 = bytes[0]
        encoded[1] = table[Int((byte0 & 0b00000111) << 2 | byte1 >> 6)]
        encoded[0] = table[Int(byte0 >> 3)]
    default: break
    }

    // padding
    let pad = Int8(UnicodeScalar("=").value)
    switch length {
    case 0:
        encoded[0] = 0
    case 1:
        encoded[2] = pad
        encoded[3] = pad
        fallthrough
    case 2:
        encoded[4] = pad
        fallthrough
    case 3:
        encoded[5] = pad
        encoded[6] = pad
        fallthrough
    case 4:
        encoded[7] = pad
        fallthrough
    default:
        encoded[8] = 0
        break
    }
    
    // return
    if let base32Encoded = String(validatingUTF8: resultBuffer) {
        resultBuffer.deallocate()
        return base32Encoded
    } else {
        resultBuffer.deallocate()
        fatalError("internal error")
    }
}

// MARK: decode

let __: UInt8 = 255
let alphabetDecodeTable: [UInt8] = [
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x20 - 0x2F
    __,__,26,27, 28,29,30,31, __,__,__,__, __,__,__,__,  // 0x30 - 0x3F
    __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x40 - 0x4F
    15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x50 - 0x5F
    __, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,  // 0x60 - 0x6F
    15,16,17,18, 19,20,21,22, 23,24,25,__, __,__,__,__,  // 0x70 - 0x7F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
]

let extendedHexAlphabetDecodeTable: [UInt8] = [
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x00 - 0x0F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x10 - 0x1F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x20 - 0x2F
    0, 1, 2, 3,  4, 5, 6, 7,  8, 9,__,__, __,__,__,__,  // 0x30 - 0x3F
    __,10,11,12, 13,14,15,16, 17,18,19,20, 21,22,23,24,  // 0x40 - 0x4F
    25,26,27,28, 29,30,31,__, __,__,__,__, __,__,__,__,  // 0x50 - 0x5F
    __,10,11,12, 13,14,15,16, 17,18,19,20, 21,22,23,24,  // 0x60 - 0x6F
    25,26,27,28, 29,30,31,__, __,__,__,__, __,__,__,__,  // 0x70 - 0x7F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x80 - 0x8F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0x90 - 0x9F
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xA0 - 0xAF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xB0 - 0xBF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xC0 - 0xCF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xD0 - 0xDF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xE0 - 0xEF
    __,__,__,__, __,__,__,__, __,__,__,__, __,__,__,__,  // 0xF0 - 0xFF
]


private func base32decode(_ string: String, _ table: [UInt8]) -> [UInt8]? {
    let length = string.unicodeScalars.count
    if length == 0 {
        return []
    }
    
    // calc padding length
    func getLeastPaddingLength(_ string: String) -> Int {
        if string.hasSuffix("======") {
            return 6
        } else if string.hasSuffix("====") {
            return 4
        } else if string.hasSuffix("===") {
            return 3
        } else if string.hasSuffix("=") {
            return 1
        } else {
            return 0
        }
    }
    
    // validate string
    let leastPaddingLength = getLeastPaddingLength(string)
    if let index = string.unicodeScalars.firstIndex(where: {$0.value > 0xff || table[Int($0.value)] > 31}) {
        // index points padding "=" or invalid character that table does not contain.
        let pos = string.unicodeScalars.distance(from: string.unicodeScalars.startIndex, to: index)
        // if pos points padding "=", it's valid.
        if pos != length - leastPaddingLength {
//            print("string contains some invalid characters.")
            return nil
        }
    }
    
    var remainEncodedLength = length - leastPaddingLength
    var additionalBytes = 0
    switch remainEncodedLength % 8 {
        // valid
    case 0: break
    case 2: additionalBytes = 1
    case 4: additionalBytes = 2
    case 5: additionalBytes = 3
    case 7: additionalBytes = 4
    default:
//        print("string length is invalid.")
        return nil
    }
    
    // validated
    let dataSize = remainEncodedLength / 8 * 5 + additionalBytes
    
    // Use UnsafePointer<UInt8>
    return string.utf8CString.withUnsafeBufferPointer {
        (data: UnsafeBufferPointer<CChar>) -> [UInt8] in
        var encoded = data.baseAddress!
        
        let result = Array<UInt8>(repeating: 0, count: dataSize)
        var decoded = UnsafeMutablePointer<UInt8>(mutating: result)
        
        // decode regular blocks
        var value0, value1, value2, value3, value4, value5, value6, value7: UInt8
        (value0, value1, value2, value3, value4, value5, value6, value7) = (0,0,0,0,0,0,0,0)
        while remainEncodedLength >= 8 {
            value0 = table[Int(encoded[0])]
            value1 = table[Int(encoded[1])]
            value2 = table[Int(encoded[2])]
            value3 = table[Int(encoded[3])]
            value4 = table[Int(encoded[4])]
            value5 = table[Int(encoded[5])]
            value6 = table[Int(encoded[6])]
            value7 = table[Int(encoded[7])]
            
            decoded[0] = value0 << 3 | value1 >> 2
            decoded[1] = value1 << 6 | value2 << 1 | value3 >> 4
            decoded[2] = value3 << 4 | value4 >> 1
            decoded[3] = value4 << 7 | value5 << 2 | value6 >> 3
            decoded[4] = value6 << 5 | value7
            
            remainEncodedLength -= 8
            decoded = decoded.advanced(by: 5)
            encoded = encoded.advanced(by: 8)
        }
        
        // decode last block
        (value0, value1, value2, value3, value4, value5, value6, value7) = (0,0,0,0,0,0,0,0)
        switch remainEncodedLength {
        case 7:
            value6 = table[Int(encoded[6])]
            value5 = table[Int(encoded[5])]
            fallthrough
        case 5:
            value4 = table[Int(encoded[4])]
            fallthrough
        case 4:
            value3 = table[Int(encoded[3])]
            value2 = table[Int(encoded[2])]
            fallthrough
        case 2:
            value1 = table[Int(encoded[1])]
            value0 = table[Int(encoded[0])]
        default: break
        }
        switch remainEncodedLength {
        case 7:
            decoded[3] = value4 << 7 | value5 << 2 | value6 >> 3
            fallthrough
        case 5:
            decoded[2] = value3 << 4 | value4 >> 1
            fallthrough
        case 4:
            decoded[1] = value1 << 6 | value2 << 1 | value3 >> 4
            fallthrough
        case 2:
            decoded[0] = value0 << 3 | value1 >> 2
        default: break
        }

        return result
    }
}

