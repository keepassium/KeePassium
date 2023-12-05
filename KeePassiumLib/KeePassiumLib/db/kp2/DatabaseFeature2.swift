//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum DatabaseFeature2 {
    case customData
    case qualityCheckFlag
    case customIconName
    case customIconModificationTime
    case previousParentGroup
    case groupTags

    var formatVersionRequired: Set<Database2.FormatVersion> {
        switch self {
        case .customData:
            return [.v4, .v4_1]
        case .qualityCheckFlag:
            return [.v4_1]
        case .customIconName, .customIconModificationTime:
            return [.v4_1]
        case .previousParentGroup:
            return [.v4_1]
        case .groupTags:
            return [.v4_1]
        }
    }
}

extension Database2.FormatVersion {

    func supports(_ feature: DatabaseFeature2) -> Bool {
        return  feature.formatVersionRequired.contains(self)
    }

    static func minimumRequired(for feature: DatabaseFeature2) -> Self {
        let possibleFormats = feature.formatVersionRequired.sorted()
        return possibleFormats.first! 
    }
}
