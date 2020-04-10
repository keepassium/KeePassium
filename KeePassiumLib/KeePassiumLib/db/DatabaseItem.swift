//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


open class DatabaseItem {
    public enum TouchMode {
        case accessed
        case modified
    }
    
    public weak var parent: Group?
    
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
