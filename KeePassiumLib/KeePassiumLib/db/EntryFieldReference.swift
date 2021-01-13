//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public class EntryFieldReference {
    public enum Status {
        case parsed
        case resolved
        case targetMissing
        case tooDeep
    }
    public enum ResolveStatus {
        case noReferences
        case hasReferences
        case brokenReferences
        case tooDeepReferences
        
        public var isError: Bool {
            switch self {
            case .noReferences,
                 .hasReferences:
                return false
            case .brokenReferences,
                 .tooDeepReferences:
                return true
            }
        }
    }
    
    private(set) public var status: Status
    
    enum FieldType {
        case uuid
        case named(_ name: String)
        case otherNamed
        
        public static func fromCode(_ code: Character) -> Self? {
            switch code {
            case "T": return .named(EntryField.title)
            case "U": return .named(EntryField.userName)
            case "P": return .named(EntryField.password)
            case "A": return .named(EntryField.url)
            case "N": return .named(EntryField.notes)
            case "I": return .uuid
            case "O": return .otherNamed
            default:
                return nil
            }
        }
    }
    
    private static let refPrefix = "{REF:"
    private static let regexp = try! NSRegularExpression(
        pattern: #"\{REF:([TUPANI])@([TUPANIO]):(.+?)\}"#,
        options: []
    )
    
    private var range: Range<String.Index>
    private var targetFieldType: FieldType
    private var searchFieldType: FieldType
    private var searchValue: Substring
    
    private init(
        range: Range<String.Index>,
        targetFieldType: FieldType,
        searchFieldType: FieldType,
        searchValue: Substring)
    {
        self.range = range
        self.targetFieldType = targetFieldType
        self.searchFieldType = searchFieldType
        self.searchValue = searchValue
        self.status = .parsed
    }
    
    
    public static func resolveReferences<T>(
        in value: String,
        entries: T,
        maxDepth: Int,
        resolvedValue: inout String
        ) -> ResolveStatus
        where T: Collection, T.Element: Entry
    {
        guard maxDepth > 0 else {
            Diag.warning("Too many chained references")
            return .tooDeepReferences
        }
        
        let refs = EntryFieldReference.parse(value)
        if refs.isEmpty { 
            resolvedValue = value
            return .noReferences
        }
        
        var status = ResolveStatus.hasReferences
        var outputValue = value
        refs.reversed().forEach { ref in
            let resolvedRefValue = ref.getResolvedValue(entries: entries, maxDepth: maxDepth - 1)
            switch ref.status {
            case .parsed:
                assertionFailure("Should be resolved")
            case .targetMissing:
                status = .brokenReferences
            case .tooDeep:
                status = .tooDeepReferences
            case .resolved:
                outputValue.replaceSubrange(ref.range, with: resolvedRefValue)
            }
        }
        resolvedValue = outputValue
        return status
    }
    
    
    private static func parse(_ string: String) -> [EntryFieldReference] {
        guard string.contains(refPrefix) else {
            return []
        }
        
        var references = [EntryFieldReference]()
        let fullRange = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regexp.matches(in: string, options: [], range: fullRange)
        for match in matches {
            guard match.numberOfRanges == 4,
                  let range = Range(match.range, in: string),
                  let targetFieldCodeRange = Range(match.range(at: 1), in: string),
                  let searchFieldCodeRange = Range(match.range(at: 2), in: string),
                  let searchValueRange =  Range(match.range(at: 3), in: string) else
            {
                continue
            }
            
            guard let targetFieldCode = string[targetFieldCodeRange].first,
                  let targetFieldType = FieldType.fromCode(targetFieldCode) else
            {
                Diag.debug("Unrecognized target field")
                continue
            }
            
            guard let searchFieldCode = string[searchFieldCodeRange].first,
                  let searchFieldType = FieldType.fromCode(searchFieldCode) else
            {
                Diag.debug("Unrecognized search field")
                continue
            }
            
            let searchValue = string[searchValueRange]
            guard !searchValue.isEmpty else {
                Diag.debug("Empty search criterion")
                continue
            }
            let ref = EntryFieldReference(
                range: range,
                targetFieldType: targetFieldType,
                searchFieldType: searchFieldType,
                searchValue: searchValue)
            references.append(ref)
        }
        return references
    }
    
    
    private func getResolvedValue<T>(entries: T, maxDepth: Int) -> String
        where T: Collection, T.Element: Entry
    {
        guard let entry = findEntry(in: entries, field: searchFieldType, value: searchValue) else {
            status = .targetMissing
            return ""
        }
        
        switch targetFieldType {
        case .uuid:
            return entry.uuid.data.asHexString
        case .named(let name):
            if let targetField = entry.getField(name) {
                let resolvedValue = targetField.resolveReferences(entries: entries, maxDepth: maxDepth - 1)
                switch targetField.resolveStatus {
                case .noReferences,
                     .hasReferences:
                    status = .resolved
                    return resolvedValue
                case .brokenReferences:
                    status = .targetMissing
                    return targetField.value
                case .tooDeepReferences:
                    status = .tooDeep
                    return targetField.value
                }

            } else {
                status = .targetMissing
                return ""
            }
        case .otherNamed:
            if let targetField = entry.getField(searchValue) {
                let resolvedValue = targetField.resolveReferences(entries: entries, maxDepth: maxDepth - 1)
                switch targetField.resolveStatus {
                case .noReferences,
                     .hasReferences:
                    status = .resolved
                    return resolvedValue
                case .brokenReferences:
                    status = .targetMissing
                    return targetField.value
                case .tooDeepReferences:
                    status = .tooDeep
                    return targetField.value
                }
            } else {
                status = .targetMissing
                return ""
            }
        }
    }
    
    private func findEntry<T>(in entries: T, field: FieldType, value: Substring) -> Entry?
        where T: Collection, T.Element: Entry
    {
        let result: Entry?
        switch field {
        case .uuid:
            let _uuid: UUID?
            if let uuidBytes = ByteArray(hexString: value) {
                _uuid = UUID(data: uuidBytes)
            } else {
                _uuid = UUID(uuidString: String(value)) 
            }
            guard let uuid = _uuid else {
                Diag.debug("Malformed UUID: \(value)")
                return nil
            }
            result = entries.first(where: { $0.uuid == uuid })
        case .named(let name):
            result = entries.first(where: { entry in
                let field = entry.getField(name)
                return field?.value.compare(value) == .some(.orderedSame)
            })
        case .otherNamed:
            result = entries.first(where: { entry in
                let field = entry.getField(value)
                return field != nil
            })
        }
        return result
    }
}

