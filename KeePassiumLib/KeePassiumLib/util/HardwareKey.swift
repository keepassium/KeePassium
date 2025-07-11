//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final public class HardwareKey: Codable, Equatable, CustomStringConvertible {
    public enum Kind: String, Codable, CustomStringConvertible {
        case yubikey
        case onlykey
        public var description: String {
            switch self {
            case .yubikey: return "YubiKey"
            case .onlykey: return "OnlyKey"
            }
        }
    }

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
        case usb
        public var description: String {
            switch self {
            case .nfc: return "NFC"
            case .mfi: return "MFI"
            case .usb: return "USB"
            }
        }
    }

    public let kind: Kind
    public let slot: Slot
    public let interface: Interface

    public init(_ kind: Kind, interface: Interface, slot: Slot) {
        self.kind = kind
        self.interface = interface
        self.slot = slot
    }

    public static func == (lhs: HardwareKey, rhs: HardwareKey) -> Bool {
        return (lhs.kind == rhs.kind) && (lhs.slot == rhs.slot) && (lhs.interface == rhs.interface)
    }

    public var description: String {
        return "\(kind.description) \(interface) Slot \(slot.number)"
    }

    public var localizedDescription: String {
        return String.localizedStringWithFormat(
            LString.hardwareKeySlotNTemplate,
            kind.description,
            slot.number
        )
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case slot
        case interface
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .yubikey
        let slot = try container.decodeIfPresent(Slot.self, forKey: .slot) ?? .slot1
        let interface = try container.decodeIfPresent(Interface.self, forKey: .interface) ?? .mfi
        self.init(kind, interface: interface, slot: slot)
    }
}

