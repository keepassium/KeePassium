//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum CommonFileFormat: CustomStringConvertible {
    case emptyFile
    case intuneProtectedFile
    case synologyBug
    case zip
    case xml
    case html
    case pdf
    case svg
    case jpeg
    case msOffice 

    public var description: String {
        switch self {
        case .emptyFile:
            return "Empty file"
        case .intuneProtectedFile:
            return "Intune-protected file"
        case .synologyBug:
            return "Synology DS File bug"
        case .zip:  return "ZIP"
        case .xml:  return "XML"
        case .html: return "HTML"
        case .pdf:  return "PDF"
        case .svg:  return "SVG"
        case .jpeg: return "JPEG"
        case .msOffice: return "MS Office"
        }
    }
}

public final class FileFormatRecognizer {
    private struct KnownSignature: Hashable {
        var signature: UInt64
        var mask: UInt64
        var format: CommonFileFormat

        init(_ signature: UInt64, _ mask: UInt64, _ format: CommonFileFormat) {
            self.signature = signature
            self.mask = mask
            self.format = format
        }
    }

    private static let knownFormats = [
        KnownSignature(0x004d534d414d4152, 0xffffffffffffffff, .intuneProtectedFile),
        KnownSignature(0x7b226572726f7222, 0xffffffffffffffff, .synologyBug),
        KnownSignature(0x504b030400000000, 0xffffffff00000000, .zip),
        KnownSignature(0x3c3f786d6c207665, 0xffffffffffffffff, .xml),  
        KnownSignature(0x3c21444f43545950, 0xffffffffffffffff, .html), 
        KnownSignature(0x3c68746d6c3e0000, 0xffffffffffff0000, .html), 
        KnownSignature(0x255044462d312e00, 0xffffffffffffff00, .pdf),  
        KnownSignature(0x3c73766720786d6c, 0xffffffffffffffff, .svg),  
        KnownSignature(0xffd8ff0000000000, 0xffffff0000000000, .jpeg),
        KnownSignature(0xd0cf11e0a1b11ae1, 0xffffffffffffffff, .msOffice),
    ]

    public static func recognize(_ signature: ByteArray) -> CommonFileFormat? {
        if signature.count == 0 {
            return .emptyFile
        }
        guard signature.count == 8,
              let testSignature = UInt64(data: signature)?.bigEndian
        else {
            assertionFailure("Expecting strictly 8-byte signatures")
            return nil
        }

        let matchingSignature = knownFormats.first { format in
            (format.signature & format.mask) == (testSignature & format.mask)
        }
        return matchingSignature?.format
    }
}
