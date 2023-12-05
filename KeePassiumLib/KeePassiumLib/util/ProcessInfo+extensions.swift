//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension ProcessInfo {

    public static var isRunningOnMac: Bool {
        return isiPadAppOnMac || isCatalystApp
    }

    public static var isiPadAppOnMac: Bool {
        guard #available(iOS 14, *) else {
            return false
        }
        return ProcessInfo.processInfo.isiOSAppOnMac
    }

    public static var isCatalystApp: Bool {
        guard #available(iOS 13, *) else {
            return false
        }
        return ProcessInfo.processInfo.isMacCatalystApp && !isiPadAppOnMac
    }

    public static var isTestFlightApp: Bool {
        assert(AppGroup.isMainApp, "This won't work correctly in extensions.")
        guard isCatalystApp else {
            let lastPathComp = Bundle.main.appStoreReceiptURL?.lastPathComponent
            return lastPathComp == "sandboxReceipt"
        }

        #if targetEnvironment(macCatalyst)
        /* Based on https://gist.github.com/lukaskubanek/cbfcab29c0c93e0e9e0a16ab09586996 */
        var code: SecStaticCode?
        var status = SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code)
        guard status == noErr, let code = code else {
            return false
        }

        var requirement: SecRequirement?
        status = SecRequirementCreateWithString(
            "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.25.1]" as CFString,
            [], 
            &requirement
        )

        guard status == noErr, let requirement = requirement else {
            return false
        }
        status = SecStaticCodeCheckValidity(code, [], requirement)
        return status == errSecSuccess
        #else
        assertionFailure("Should not be here")
        return false
        #endif
    }
}
