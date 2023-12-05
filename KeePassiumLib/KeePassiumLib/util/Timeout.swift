//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public struct Timeout {
    public private(set) var duration: TimeInterval

    public private(set) var startTime: DispatchTime
    public var deadline: DispatchTime {
        let durationInMicroseconds = Int(duration * 1.0e6)
        return startTime.advanced(by: .microseconds(durationInMicroseconds))
    }

    public var remainingTimeInterval: TimeInterval {
        let remaining = DispatchTime.now().distance(to: deadline)
        switch remaining {
        case .seconds(let value):
            return TimeInterval(value)
        case .milliseconds(let value):
            return TimeInterval(value) / 1.0e3
        case .microseconds(let value):
            return TimeInterval(value) / 1.0e6
        case .nanoseconds(let value):
            return TimeInterval(value) / 1.0e9
        case .never:
            return .greatestFiniteMagnitude
        }
    }

    public init(startTime: DispatchTime = .now(), duration: TimeInterval) {
        self.duration = duration
        self.startTime = startTime
    }
}
