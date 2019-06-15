//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum ProgressInterruption: LocalizedError {
    case cancelled(reason: ProgressEx.CancellationReason)
    
    public var errorDescription: String? {
        switch self {
        case .cancelled(let reason):
            return reason.localizedDescription
        }
    }
}
