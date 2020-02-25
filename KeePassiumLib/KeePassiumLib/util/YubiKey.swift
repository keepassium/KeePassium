//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class YubiKey: Codable, Equatable, CustomStringConvertible {
    public let name = "YubiKey"
    
    public enum Slot: Int, Codable {
        case slot1 = 1
        case slot2 = 2
        public var number: Int {
            return rawValue
        }
    }
    
    public enum Interface: Int, Codable, CustomStringConvertible {
        case nfc
        case mfi
        public var description: String {
            switch self {
            case .nfc: return "NFC"
            case .mfi: return "MFI"
            }
        }
    }
    
    public var slot: Slot
    public var interface: Interface
    
    private enum CodingKeys: String, CodingKey {
        case slot
        case interface
    }
    
    public init(interface: Interface, slot: Slot) {
        self.interface = interface
        self.slot = slot
    }
    
    public static func == (lhs: YubiKey, rhs: YubiKey) -> Bool {
        return (lhs.slot == rhs.slot) && (lhs.interface == rhs.interface)
    }
    
    public var description: String {
        return "YubiKey \(interface) Slot \(slot.number)"
    }
}

