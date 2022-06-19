//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum PremiumFeature: Int {
    public static let all: [PremiumFeature] = [
        .canUseMultipleDatabases, 
        .canUseLongDatabaseTimeouts, 
        .canPreviewAttachments, 
        .canUseHardwareKeys,    
        .canKeepMasterKeyOnDatabaseTimeout, 
        .canChangeAppIcon,
        .canViewFieldReferences,
        .canRelocateAcrossDatabases,
        .canUseQuickTypeAutoFill,
    ]
    public static let introductionDate: [PremiumFeature : Date] = [
        .canUseMultipleDatabases: Date(iso8601string: "2019-07-31T00:00:00Z")!,
        .canUseLongDatabaseTimeouts: Date(iso8601string: "2019-07-31T00:00:00Z")!,
        .canPreviewAttachments: Date(iso8601string: "2019-07-31T00:00:00Z")!,
        .canUseHardwareKeys: Date(iso8601string: "2020-01-14T00:00:00Z")!,
        .canKeepMasterKeyOnDatabaseTimeout: Date(iso8601string: "2020-07-14T00:00:00Z")!,
        .canChangeAppIcon: Date(iso8601string: "2020-08-04T00:00:00Z")!,
        .canUseExpressUnlock: Date(iso8601string: "2020-10-01T00:00:00Z")!,
        .canViewFieldReferences: Date(iso8601string: "2020-11-12T00:00:00Z")!,
        .canRelocateAcrossDatabases: Date(iso8601string: "2021-10-08T00:00:00Z")!,
        .canUseQuickTypeAutoFill: Date(iso8601string: "2021-11-19T00:00:00Z")!,
    ]
    
    case canUseMultipleDatabases = 0

    case canUseLongDatabaseTimeouts = 2
    
    case canPreviewAttachments = 3
    
    case canUseHardwareKeys = 4
    
    case canKeepMasterKeyOnDatabaseTimeout = 5
    
    case canChangeAppIcon = 6
    
    case canUseExpressUnlock = 7
    
    case canViewFieldReferences = 8
    
    case canRelocateAcrossDatabases = 9
    
    case canUseQuickTypeAutoFill = 10
    
    public func isAvailable(in status: PremiumManager.Status, fallbackDate: Date?) -> Bool {
        let isEntitled = status == .subscribed ||
            status == .lapsed ||
            wasAvailable(before: fallbackDate)
        
        switch self {
        case .canUseMultipleDatabases,
             .canUseLongDatabaseTimeouts,
             .canUseHardwareKeys,
             .canKeepMasterKeyOnDatabaseTimeout,
             .canChangeAppIcon,
             .canViewFieldReferences,
             .canRelocateAcrossDatabases,
             .canUseQuickTypeAutoFill:
            return isEntitled
        case .canPreviewAttachments:
            return true 
        case .canUseExpressUnlock:
            return true 
        }
    }
    
    private func wasAvailable(before fallbackDate: Date?) -> Bool {
        guard let date = fallbackDate else {
            return false
        }
        guard let introductionDate = PremiumFeature.introductionDate[self] else {
            assertionFailure("No introduction date for the feature \(self)")
            return false
        }
        return date > introductionDate
    }
}
