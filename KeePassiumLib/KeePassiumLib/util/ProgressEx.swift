//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class ProgressEx: Progress {
    public var status: String {
        get { return localizedDescription }
        set { localizedDescription = newValue }
    }
    
    override public init(parent parentProgressOrNil: Progress?,
                  userInfo userInfoOrNil: [ProgressUserInfoKey : Any]? = nil)
    {
        super.init(parent: parentProgressOrNil, userInfo: userInfoOrNil)
    }
}

