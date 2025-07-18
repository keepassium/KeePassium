//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

open class DatabaseItem: Taggable {
    public enum TouchMode {
        case accessed
        case modified
        case modifiedAt(_ date: Date)
    }

    public weak var parent: Group?

    public var tags: [String] = []

    public func resolvingTags() -> [String] {
        var resolvedTags = tags
        var parent = parent
        while parent != nil {
            parent?.tags.forEach {
                if !resolvedTags.contains($0) {
                    resolvedTags.append($0)
                }
            }
            parent = parent?.parent
        }
        return resolvedTags
    }

    public func isAncestor(of item: DatabaseItem) -> Bool {
        var parent = item.parent
        while parent != nil {
            if self === parent {
                return true
            }
            parent = parent?.parent
        }
        return false
    }

    public func touch(_ mode: TouchMode, updateParents: Bool = true) {
        fatalError("Pure abstract method")
    }

}
