//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

private let singlelineFields: [String] =
    [EntryField.title, EntryField.userName, EntryField.password, EntryField.url]

protocol ViewableField: AnyObject {
    var field: EntryField? { get set }

    var internalName: String { get }
    var visibleName: String { get }

    var value: String? { get }
    var resolvedValue: String? { get }
    var decoratedResolvedValue: String? { get }

    var isProtected: Bool { get }

    var isEditable: Bool { get }

    var isMultiline: Bool { get }

    var isFixed: Bool { get }

    var isValueHidden: Bool { get set }

    var isAuditable: Bool { get set }

    var isHeightConstrained: Bool { get set }
}

extension ViewableField {
    var isMultiline: Bool {
        return !singlelineFields.contains(internalName)
    }

}

class BasicViewableField: ViewableField {
    weak var field: EntryField?

    var internalName: String { return field?.name ?? "" }
    var visibleName: String { return field?.visibleName ?? "" }
    var value: String? { return field?.value }
    var resolvedValue: String? { return field?.resolvedValue }
    var decoratedResolvedValue: String? { return field?.decoratedResolvedValue }
    var isProtected: Bool { return field?.isProtected ?? false }
    var isFixed: Bool {
        guard let field else { return false }
        return field.isStandardField || field.name == EntryField.tags
    }

    var isValueHidden: Bool

    var isAuditable: Bool = true

    var isHeightConstrained: Bool

    var isEditable: Bool { return true }

    convenience init(field: EntryField, isValueHidden: Bool) {
        self.init(fieldOrNil: field, isValueHidden: isValueHidden)
    }

    init(fieldOrNil field: EntryField?, isValueHidden: Bool) {
        self.field = field
        self.isValueHidden = isValueHidden
        self.isHeightConstrained = true
    }
}

class PasskeyViewableField: BasicViewableField {
    private let passkey: Passkey

    public var relyingParty: String { passkey.relyingParty }
    public var username: String { passkey.username }

    override var internalName: String { EntryField.passkey }
    override var visibleName: String { LString.fieldPasskey }
    override var value: String? {
        [relyingParty, username].joined(separator: "\n")
    }
    override var resolvedValue: String? { value }
    override var isProtected: Bool { false }
    override var isFixed: Bool { true }
    override var isEditable: Bool { false }

    init(passkey: Passkey) {
        self.passkey = passkey
        super.init(fieldOrNil: nil, isValueHidden: false)
        isAuditable = false
    }
}

class DynamicViewableField: BasicViewableField, Refreshable {

    internal var fields: [Weak<EntryField>]

    init(field: EntryField?, fields: [EntryField], isValueHidden: Bool) {
        self.fields = Weak.wrapped(fields)
        super.init(fieldOrNil: field, isValueHidden: isValueHidden)
    }

    public func refresh() {
    }
}

class TOTPViewableField: DynamicViewableField {
    var totpGenerator: TOTPGenerator?

    override var internalName: String { return EntryField.totp }
    override var visibleName: String { return LString.fieldOTP }

    override var isEditable: Bool { return false }

    override var value: String {
        return totpGenerator?.generate() ?? ""
    }
    override var resolvedValue: String? {
        return value
    }
    override var decoratedResolvedValue: String? {
        return value
    }

    var elapsedTimeFraction: Double? {
        return totpGenerator?.elapsedTimeFraction
    }

    init(fields: [EntryField]) {
        super.init(field: nil, fields: fields, isValueHidden: false)
        refresh()
    }

    override func refresh() {
        let _fields = Weak.unwrapped(self.fields)
        self.totpGenerator = TOTPGeneratorFactory.makeGenerator(from: _fields) 
    }
}

class ViewableEntryFieldFactory {
    enum ExcludedFields {
        case title
        case emptyValues
        case nonEditable
        case otpConfig
        case passkeyConfig
    }

    static func makeAll(
        from entry: Entry,
        in database: Database,
        excluding excludedFields: [ExcludedFields]
    ) -> [ViewableField] {
        var result = [ViewableField]()

        let hasValidOTPConfig = TOTPGeneratorFactory.makeGenerator(for: entry) != nil
        let passkey = Passkey.make(from: entry)
        let hasValidPasskeyConfig = passkey != nil
        let isAuditable = (entry as? Entry2)?.qualityCheck ?? true

        var excludedFieldNames = Set<String>()
        if excludedFields.contains(.title) {
            excludedFieldNames.insert(EntryField.title)
        }
        if hasValidOTPConfig && excludedFields.contains(.otpConfig) {
            excludedFieldNames.insert(EntryField.otpConfig1)
            excludedFieldNames.insert(EntryField.otpConfig2Seed)
            excludedFieldNames.insert(EntryField.otpConfig2Settings)
            excludedFieldNames.insert(EntryField.timeOtpLength)
            excludedFieldNames.insert(EntryField.timeOtpPeriod)
            excludedFieldNames.insert(EntryField.timeOtpSecret)
            excludedFieldNames.insert(EntryField.timeOtpAlgorithm)
        }
        if hasValidPasskeyConfig && excludedFields.contains(.passkeyConfig) {
            excludedFieldNames.formUnion([
                EntryField.passkeyCredentialID,
                EntryField.passkeyRelyingParty,
                EntryField.passkeyPrivateKeyPEM,
                EntryField.passkeyUserHandle,
                EntryField.passkeyUsername,
            ])
        }
        let excludeEmptyValues = excludedFields.contains(.emptyValues)
        let excludeNonEditable = excludedFields.contains(.nonEditable)
        for field in entry.fields {
            if excludedFieldNames.contains(field.name) {
                continue
            }
            if excludeEmptyValues && field.value.isEmpty {
                continue
            }

            let viewableField = makeOne(field: field)
            viewableField.isAuditable = isAuditable
            result.append(viewableField)
        }

        if hasValidOTPConfig && !excludeNonEditable {
            result.append(TOTPViewableField(fields: entry.fields))
        }
        if let passkey,
           !excludeNonEditable
        {
            result.append(PasskeyViewableField(passkey: passkey))
        }
        return result
    }

    static func makeTags(from entry: Entry, parent: Group?, includeEmpty: Bool) -> (EntryField, ViewableField)? {
        let tags = entry.tags
        guard !tags.isEmpty || includeEmpty else {
            return nil
        }

        let entryField = EntryField(
            name: EntryField.tags,
            value: TagHelper.tagsToString(tags),
            isProtected: false
        )
        let viewableField = BasicViewableField(fieldOrNil: entryField, isValueHidden: false)
        return (entryField, viewableField)
    }

    static private func makeOne(field: EntryField) -> ViewableField {
        let isHidden =
            (field.isProtected || field.name == EntryField.password)
            && Settings.current.isHideProtectedFields
        let result = BasicViewableField(field: field, isValueHidden: isHidden)

        if field.name == EntryField.notes {
            result.isHeightConstrained = Settings.current.isCollapseNotesField
        }
        return result
    }
}
