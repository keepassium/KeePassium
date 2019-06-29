//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

fileprivate let singlelineFields: [String] =
    [EntryField.title, EntryField.userName, EntryField.password, EntryField.url]

protocol ViewableField: class {
    var field: EntryField? { get set }

    var internalName: String { get }
    var visibleName: String { get }
    
    var value: String? { get }
    var isProtected: Bool { get }
    
    var isEditable: Bool { get }

    var isMultiline: Bool { get }

    var isFixed: Bool { get }
    
    var isValueHidden: Bool { get set }

}

extension ViewableField {
    var isMultiline: Bool {
        return !singlelineFields.contains(internalName)
    }
    
    var visibleName: String {
        switch internalName {
        case EntryField.title: return LString.fieldTitle
        case EntryField.userName: return LString.fieldUserName
        case EntryField.password: return LString.fieldPassword
        case EntryField.url: return LString.fieldURL
        case EntryField.notes: return LString.fieldNotes
        default:
            return internalName
        }
    }
}

class BasicViewableField: ViewableField {
    weak var field: EntryField?
    
    var internalName: String { return field?.name ?? "" }
    var value: String? { return field?.value }
    var isProtected: Bool { return field?.isProtected ?? false }
    var isFixed: Bool { return field?.isStandardField ?? false }

    var isValueHidden: Bool

    var isEditable: Bool { return true }
    
    convenience init(field: EntryField, isValueHidden: Bool) {
        self.init(fieldOrNil: field, isValueHidden: isValueHidden)
    }
    
    init(fieldOrNil field: EntryField?, isValueHidden: Bool) {
        self.field = field
        self.isValueHidden = isValueHidden
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
    override var isEditable: Bool { return false }
    
    override var value: String {
        return totpGenerator?.generate() ?? ""
    }
    var elapsedTimeFraction: Float? {
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
    }
    
    static func makeAll(
        from entry: Entry,
        in database: Database,
        excluding excludedFields: [ExcludedFields]
    ) -> [ViewableField] {
        var result = [ViewableField]()
        let excludeTitle = excludedFields.contains(.title)
        let excludeEmptyValues = excludedFields.contains(.emptyValues)
        let excludeNonEditable = excludedFields.contains(.nonEditable)
        for field in entry.fields {
            if excludeTitle && field.name == EntryField.title {
                continue
            }
            if excludeEmptyValues && field.value.isEmpty {
                continue
            }
            
            let isHidden = field.isProtected || field.name == EntryField.password
            let viewableField = BasicViewableField(field: field, isValueHidden: isHidden)
            result.append(viewableField)
        }
        
        if let _ = TOTPGeneratorFactory.makeGenerator(for: entry),
            !excludeNonEditable
        {
            result.append(TOTPViewableField(fields: entry.fields))
        }
        
        return result
    }
}

