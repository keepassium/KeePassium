//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
#if INTUNE
import IntuneMAMSwift
#endif

class AppInfo {
    public static var name: String { return nvb.name }
    public static var version: String { return nvb.version }
    public static var build: String { return nvb.build }

    private struct NameVersionBuild {
        let name: String
        let version: String
        let build: String
    }

    private static let nvb = loadInfo()

    private static func loadInfo() -> NameVersionBuild {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "KeePassium"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return NameVersionBuild(name: appName, version: appVersion, build: buildVersion)
    }

    public static var description: String {
        var envInfo = String()
        if ProcessInfo.isCatalystApp {
            envInfo = "MacCatalyst \(UIDevice.current.systemVersion)"
        } else if ProcessInfo.isiPadAppOnMac {
            envInfo = "Mac, iPadOS \(UIDevice.current.systemVersion)"
        } else {
            envInfo = "\(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)"
        }
        #if INTUNE
        envInfo += ", Intune \(IntuneMAMVersionInfo.sdkVersion())"
        #endif
        if AppGroup.isAppExtension {
            envInfo += String(format: ", using %.1f MiB", MemoryMonitor.getMemoryFootprintMiB())
        }

        let betaMark = Settings.current.isTestEnvironment ? "-beta" : ""
        return "\(name) v\(version).\(build)\(betaMark) (\(envInfo))"
    }
}
