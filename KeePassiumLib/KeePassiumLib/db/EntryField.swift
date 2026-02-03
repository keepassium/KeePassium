//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public class EntryField: Eraseable, Codable {
    public static let title    = "Title"
    public static let userName = "UserName"
    public static let password = "Password"
    public static let url      = "URL"
    public static let notes    = "Notes"
    public static let standardNames = [title, userName, password, url, notes]

    public static let totp = "TOTP"
    public static let otp = "otp"

    public static let tags = "tags" + UUID().uuidString

    public static let passkey = "passkey" + UUID().uuidString

    public static let kp2aURLPrefix = "KP2A_URL"

    public static let protectedValueMask = "* * * *"

    private static let excludedFromCopying: Set<String> = [
        EntryField.title,
        EntryField.otpConfig1,
        EntryField.otpConfig2Seed,
        EntryField.otpConfig2Settings,
        EntryField.timeOtpLength,
        EntryField.timeOtpPeriod,
        EntryField.timeOtpPeriod,
        EntryField.timeOtpSecret,
        EntryField.timeOtpAlgorithm,
        EntryField.passkeyCredentialID,
        EntryField.passkeyRelyingParty,
        EntryField.passkeyPrivateKeyPEM,
        EntryField.passkeyUserHandle,
        EntryField.passkeyUsername,
        EntryField.passkeyFlagBE,
        EntryField.passkeyFlagBS,
    ]

    public var name: String
    public var value: String {
        didSet {
            resolvedValueInternal = value
        }
    }
    public var isProtected: Bool

    public var visibleName: String {
        return Self.getVisibleName(for: name)
    }

    public class func getVisibleName(for fieldName: String) -> String {
        switch fieldName {
        case Self.title: return LString.fieldTitle
        case Self.userName: return LString.fieldUserName
        case Self.password: return LString.fieldPassword
        case Self.url: return LString.fieldURL
        case Self.notes: return LString.fieldNotes
        case Self.otp: return LString.fieldOTP
        case Self.tags: return LString.fieldTags
        default:
            if let urlIndex = getExtraURLIndex(from: fieldName) {
                return String.localizedStringWithFormat(LString.titleExtraURLTitleTemplate, urlIndex + 1)
            }
            return fieldName
        }
    }

    public var isExtraURL: Bool {
        return Self.getExtraURLIndex(from: name) != nil
    }

    public static func getExtraURLIndex(from fieldName: String) -> Int? {
        guard fieldName.hasPrefix(Self.kp2aURLPrefix) else {
            return nil
        }

        if fieldName == Self.kp2aURLPrefix {
            return 0
        } else {
            let indexString = String(fieldName.split(separator: "_").last ?? "0")
            return Int(indexString) ?? 0
        }
    }

    public static func isExcludedFromCopying(_ fieldName: String) -> Bool {
        return excludedFromCopying.contains(fieldName)
    }

    internal var resolvedValueInternal: String?

    public var resolvedValue: String {
        guard resolvedValueInternal != nil else {
            assertionFailure()
            return value
        }
        return resolvedValueInternal!
    }

    public var decoratedResolvedValue: String {
        if hasReferences {
            return "→ " + resolvedValue
        } else {
            return resolvedValue
        }
    }

    private(set) public var resolveStatus = EntryFieldReference.ResolveStatus.noReferences

    public var hasReferences: Bool {
        return resolveStatus != .noReferences
    }

    public var isStandardField: Bool {
        return EntryField.isStandardName(name: self.name)
    }
    public static func isStandardName(name: String) -> Bool {
        return standardNames.contains(name)
    }

    public convenience init(name: String, value: String, isProtected: Bool) {
        self.init(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: value,
            resolveStatus: .noReferences
        )
    }

    internal init(
        name: String,
        value: String,
        isProtected: Bool,
        resolvedValue: String?,
        resolveStatus: EntryFieldReference.ResolveStatus
    ) {
        self.name = name
        self.value = value
        self.isProtected = isProtected
        self.resolvedValueInternal = resolvedValue
        self.resolveStatus = resolveStatus
    }

    deinit {
        erase()
    }

    public func clone() -> EntryField {
        let clone = EntryField(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: resolvedValue,
            resolveStatus: resolveStatus
        )
        return clone
    }

    public func erase() {
        name.erase()
        value.erase()
        isProtected = false

        resolvedValueInternal?.erase()
        resolvedValueInternal = nil
        resolveStatus = .noReferences
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case value
        case isProtected
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
        self.isProtected = try container.decode(Bool.self, forKey: .isProtected)
    }

    public func contains(
        textWord: Substring,
        scope: SearchQuery.FieldScope,
        options: String.CompareOptions
    ) -> Bool {
        if name == EntryField.password && !scope.contains(.passwordField) {
            return false
        }

        if scope.contains(.fieldNames)
           && !isStandardField
           && name.localizedContains(textWord, options: options)
        {
            return true
        }

        let includeFieldValue = !isProtected || scope.contains(.protectedValues)
        if includeFieldValue {
            return resolvedValue.localizedContains(textWord, options: options)
        }
        return false
    }

    @discardableResult
    public func resolveReferences<T>(
        referrer: Entry,
        entries: T,
        maxDepth: Int = 3
    ) -> String where T: Collection, T.Element: Entry {
        guard resolvedValueInternal == nil else {
            return resolvedValueInternal!
        }

        var _resolvedValue = value
        let status = EntryFieldReference.resolveReferences(
            in: value,
            referrer: referrer,
            entries: entries,
            maxDepth: maxDepth,
            resolvedValue: &_resolvedValue
        )
        resolveStatus = status
        resolvedValueInternal = _resolvedValue
        return _resolvedValue
    }

    public func unresolveReferences() {
        resolvedValueInternal = nil
        resolveStatus = .noReferences
    }
}

extension EntryField: Equatable, Hashable {
    public static func == (lhs: EntryField, rhs: EntryField) -> Bool {
        return lhs.name == rhs.name
            && lhs.value == rhs.value
            && lhs.isProtected == rhs.isProtected
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
        hasher.combine(isProtected)
    }
}
