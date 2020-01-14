//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import LocalAuthentication

class SystemIssueDetector {
    public enum Issue {
        static let allValues: [Issue] = [.autoFillFaceIDLoop_iOS_13_1_3]
        
        case autoFillFaceIDLoop_iOS_13_1_3
    }
    
    private static var activeIssues = [Issue]()
    
    public static func isAffectedBy(_ issue: Issue) -> Bool {
        return activeIssues.contains(issue)
    }
    
    public static func scanForIssues() {
        assert(activeIssues.isEmpty)
        for issue in Issue.allValues {
            switch issue {
            case .autoFillFaceIDLoop_iOS_13_1_3:
                if isAffectedByAutoFillFaceIDLoop_iOS_13_1_3() {
                    Diag.warning("Detected a known system issue: \(issue)")
                    Settings.current.isAffectedByAutoFillFaceIDLoop_iOS_13_1_3 = true
                    activeIssues.append(.autoFillFaceIDLoop_iOS_13_1_3)
                }
            }
        }
    }
    
    private static func isAffectedByAutoFillFaceIDLoop_iOS_13_1_3() -> Bool {
        #if AUTOFILL_EXT
            guard #available(iOS 13.1.3, *) else { return false }
            guard LAContext.getBiometryType() == .faceID else { return false }
            return true
        #else
            return false
        #endif
    }
}
