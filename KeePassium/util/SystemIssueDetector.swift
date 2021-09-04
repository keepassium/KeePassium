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
        static let allValues: [Issue] = [.autoFillBiometricIDLoop]
        
        case autoFillBiometricIDLoop
    }
    
    private static var activeIssues = [Issue]()
    
    public static func isAffectedBy(_ issue: Issue) -> Bool {
        return activeIssues.contains(issue)
    }
    
    public static func scanForIssues() {
        assert(activeIssues.isEmpty)
        for issue in Issue.allValues {
            switch issue {
            case .autoFillBiometricIDLoop:
                if isAffectedByAutoFillBiometricIDLoop() {
                    Diag.info("Detected a known system issue: \(issue)")
                    Settings.current.isAffectedByAutoFillBiometricIDLoop = true
                    activeIssues.append(.autoFillBiometricIDLoop)
                }
            }
        }
    }
    
    private static func isAffectedByAutoFillBiometricIDLoop() -> Bool {
        #if AUTOFILL_EXT
            guard #available(iOS 13.1.3, *) else { return false }
            return true
        #else
            return false
        #endif
    }
}
