//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public typealias DailyAppUsageHistory = [Int: TimeInterval]

public class UsageMonitor {
    public enum ReportType {
        case perMonth
        case perYear

        fileprivate var scale: Double {
            switch self {
            case .perMonth:
                return 1.0
            case .perYear:
                return 12.0
            }
        }
    }
    
    private let appUseDurationKey = "dailyAppUsageDuration"
    private var startTime: Date?

    private let referenceDate = Date(timeIntervalSinceReferenceDate: 0.0)
    
    private let maxHistoryLength = 30
    
    private var cachedUsageDuration = 0.0
    private var cachedUsageDurationNeedUpdate = true
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startInterval),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopInterval),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        cleanupObsoleteData()
    }
    
    public var isEnabled: Bool {
        switch PremiumManager.shared.status {
        case .initialGracePeriod,
             .subscribed:
            return false
        case .lapsed, 
             .freeLightUse,
             .freeHeavyUse:
            return true
        }
    }
    
    
    @objc public func startInterval() {
        if isEnabled {
            startTime = Date.now
        } else {
            startTime = nil
        }
    }
    
    public func refresh() {
        guard startTime != nil else { return } 
        
        stopInterval()
        startInterval()
    }
    
    @objc public func stopInterval() {
        guard let startTime = startTime else { return }
        let endTime = Date.now
        let secondsElapsed = abs(endTime.timeIntervalSince(startTime))
        self.startTime = nil 
        
        var history = loadHistoryData()
        let todaysIndex = daysSinceReferenceDate(date: endTime)
        let todaysUsage = history[todaysIndex] ?? 0.0
        history[todaysIndex] = todaysUsage + secondsElapsed
        saveHistoryData(history)
        
        Diag.verbose(String(format: "Usage time added: %.1f s", secondsElapsed))
    }
    
    
    public func getAppUsageDuration(_ reportType: ReportType) -> TimeInterval {
        guard cachedUsageDurationNeedUpdate else {
            return cachedUsageDuration * reportType.scale
        }

        cachedUsageDuration = 0.0
        cachedUsageDurationNeedUpdate = false
        let history = loadHistoryData()
        let from = daysSinceReferenceDate(date: Date.now) - maxHistoryLength
        history.forEach { (dayIndex, dayUsage) in
            guard dayIndex > from else { return }
            cachedUsageDuration += dayUsage
        }
        return cachedUsageDuration * reportType.scale
    }
    
    private func daysSinceReferenceDate(date: Date) -> Int {
        let calendar = Calendar.current
        guard let days = calendar.dateComponents([.day], from: referenceDate, to: date).day else {
            assertionFailure()
            return 0
        }
        return days
    }
    
    
    private func loadHistoryData() -> DailyAppUsageHistory {
        guard let historyData = UserDefaults.appGroupShared.data(forKey: appUseDurationKey) else {
            return DailyAppUsageHistory()
        }
        guard let history = NSKeyedUnarchiver.unarchiveObject(with: historyData)
            as? DailyAppUsageHistory else
        {
            assertionFailure()
            Diag.warning("Failed to parse history data, ignoring.")
            return DailyAppUsageHistory()
        }
        return history
    }
    
    private func saveHistoryData(_ history: DailyAppUsageHistory) {
        let historyData = NSKeyedArchiver.archivedData(withRootObject: history)
        UserDefaults.appGroupShared.set(historyData, forKey: appUseDurationKey)
        cachedUsageDurationNeedUpdate = true
    }
    
    private func cleanupObsoleteData() {
        let history = loadHistoryData()
        guard history.keys.count > maxHistoryLength else {
            return
        }
        
        let earliestDayIndexToKeep = daysSinceReferenceDate(date: Date.now) - maxHistoryLength
        let trimmedHistory = history.filter { (dayIndex, dayUsage) in
            let shouldKeep = dayIndex < earliestDayIndexToKeep
            return shouldKeep
        }
        Diag.debug("Usage stats trimmed from \(history.keys.count) to \(trimmedHistory.keys.count) entries")
        saveHistoryData(trimmedHistory)
    }
    
    #if DEBUG
    public func resetStats() {
        let emptyHistory = DailyAppUsageHistory()
        saveHistoryData(emptyHistory)
    }
    #endif
}
