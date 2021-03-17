//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import StoreKit

final public class StoreReviewSuggester {
    private static let defaultsKey = "storeReviewSuggester"
    private static let reviewFrequency = 0.015 
    
    private static let minDaysSinceReview = 125 
    private static let minSessionsSinceReview = 10
    private static let minDaysSinceTrouble = 7
    private static let minSessionsSinceTrouble = 10
    
    private static let minIntervalSinceReview = TimeInterval(minDaysSinceReview * 24 * 3600)
    private static let minIntervalSinceTrouble = TimeInterval(minDaysSinceTrouble * 24 * 3600)
    
    public enum EventType {
        case sessionStart
        case trouble
        case reviewRequest
    }
    
    public enum Occasion {
        case didOpenDatabase
        case didPurchasePremium
        case didEditItem
    }
    
    private struct Parameters: Codable, CustomDebugStringConvertible {
        var lastReviewedVersion: String
        var lastReviewDate: Date
        var sessionsSinceReview: Int
        var lastTroubleDate: Date
        var sessionsSinceTrouble: Int
        
        var debugDescription: String {
            return """
                {
                    lastReviewedVersion: \(lastReviewedVersion),
                    lastReviewDate: \(lastReviewDate),
                    sessionsSinceReview: \(sessionsSinceReview),
                    lastTroubleDate: \(lastTroubleDate),
                    sessionsSinceTrouble: \(sessionsSinceTrouble),
                }
                """
        }
    }
    
    
    private static func withParams(_ handler: (inout Parameters) -> Void) {
        var params = getParams()
        handler(&params)
        setParams(params)
    }
    
    private static func getParams() -> Parameters {
        let defaults = UserDefaults.appGroupShared
        if let storedParamsData = defaults.object(forKey: defaultsKey) as? Data {
            let decoder = JSONDecoder()
            if let storedParams = try? decoder.decode(Parameters.self, from: storedParamsData) {
                return storedParams
            } else {
                Diag.warning("Invalid format of stored params")
                assertionFailure()
            }
        }
        
        let params = Parameters(
            lastReviewedVersion: "1.21",
            lastReviewDate: Date.now.addingTimeInterval(-minIntervalSinceReview),
            sessionsSinceReview: 0,
            lastTroubleDate: Date.now,
            sessionsSinceTrouble: 0
        )
        Diag.debug("Store review suggester initialized")
        return params
    }
    
    private static func setParams(_ params: Parameters) {
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(params) else {
            Diag.warning("Failed to encode params")
            assertionFailure()
            return
        }
        UserDefaults.appGroupShared.set(encodedData, forKey: defaultsKey)
    }
    
    
    public static func registerEvent(_ event: EventType) {
        switch event {
        case .sessionStart:
            withParams {
                $0.sessionsSinceReview += 1
                $0.sessionsSinceTrouble += 1
            }
        case .trouble:
            withParams {
                $0.lastTroubleDate = Date.now
                $0.sessionsSinceTrouble = 0
            }
        case .reviewRequest:
            withParams {
                $0.lastReviewDate = Date.now
                $0.sessionsSinceReview = 0
            }
        }
    }
    
    public static func maybeShowAppReview(appVersion: String, occasion: Occasion) {
        guard isGoodTimeForReview(appVersion: appVersion) else {
            return
        }
        
        let weekNumberBase4 = Date.now.iso8601WeekOfYear % 4
        switch (occasion, weekNumberBase4) {
        case (.didOpenDatabase, 0),    
             (.didPurchasePremium, 1), 
             (.didEditItem, 2):        
            break
        case (_, 3):  
            return
        default:
            return
        }
        
        let shouldShowReview = Double.random(in: 0..<1) < reviewFrequency
        if shouldShowReview {
            showAppReview(appVersion: appVersion)
        }
    }
    
    private static func showAppReview(appVersion: String) {
        registerEvent(.reviewRequest)
        withParams {
            $0.lastReviewedVersion = appVersion
        }
        SKStoreReviewController.requestReview()
    }
    
    private static func isGoodTimeForReview(appVersion: String) -> Bool {
        let params = getParams()
        let timeSinceReview = Date.now.timeIntervalSince(params.lastReviewDate)
        let timeSinceTrouble = Date.now.timeIntervalSince(params.lastTroubleDate)
        
        guard appVersion != params.lastReviewedVersion else {
            return false
        }
        
        guard timeSinceReview > minIntervalSinceReview else {
            return false
        }
        
        guard params.sessionsSinceReview > minSessionsSinceReview else {
            return false
        }
        
        guard timeSinceTrouble > minIntervalSinceTrouble &&
              params.sessionsSinceTrouble > minSessionsSinceTrouble
        else {
            return false
        }
        
        return true
    }
}
