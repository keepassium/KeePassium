//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIDevice {
    public static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")

    public func hasHomeButton() -> Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        let windows = AppGroup.applicationShared?
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let keyWindow = windows?.first(where: { $0.isKeyWindow }) else {
            return false
        }
        return keyWindow.safeAreaInsets.bottom.isZero
        #endif
    }

    public func bootTime() -> Date? {
        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &bootTime, &bootTimeSize, nil, 0) == KERN_SUCCESS,
              bootTimeSize == MemoryLayout<timeval>.stride,
              bootTime.tv_sec != 0
        else {
            return nil
        }
        let fullEpochSeconds = TimeInterval(bootTime.tv_sec)
        let fractionEpochSecond = TimeInterval(bootTime.tv_usec) / 1e6
        return Date(timeIntervalSince1970: fullEpochSeconds + fractionEpochSecond)
    }
}
