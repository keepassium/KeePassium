//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum Result<ReturnType, ErrorType> {
    case success(_ output: ReturnType)
    case failure(_ error: ErrorType)
}

extension Result where ReturnType == Void {
    static var success: Result {
        return .success(())
    }
}
