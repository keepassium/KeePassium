//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol Taggable {
    var tags: [String] { get set }
}

extension Taggable {
    func parseItemTags(xml element: AEXMLElement) -> [String] {
        assert(element.name == Xml2.tags)
        return TagHelper.stringToTags(element.value)
    }

    func itemTagsToString(_ tags: [String]) -> String {
        return TagHelper.tagsToString(tags)
    }
}

public enum TagHelper {
    public static func stringToTags(_ tagsString: String?) -> [String] {
        guard let tagsString, tagsString.isNotEmpty else {
            return []
        }
        let rawTags = tagsString.components(separatedBy: .init(charactersIn: ",;"))
        let trimmedTags = rawTags
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isNotEmpty }
        return trimmedTags
    }

    public static func tagsToString(_ tags: [String]) -> String {
        return tags.joined(separator: ",")
    }
}
