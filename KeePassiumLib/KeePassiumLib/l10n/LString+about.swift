//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {
    public enum About {
        public static let titlePrivacyPolicy = NSLocalizedString(
            "[PrivacyPolicy/title]",
            bundle: Bundle.framework,
            value: "Privacy Policy",
            comment: "Section: privacy policy")
        
        public static let offlinePrivacyPolicyText = NSLocalizedString(
            "[PrivacyPolicy/Offline/text]",
            bundle: Bundle.framework,
            value: "KeePassium does not collect any personal or analytical data nor share it with anyone.",
            comment: "A brief summary of the privacy policy (for offline mode)")
        public static let onlinePrivacyPolicyText = NSLocalizedString(
            "[PrivacyPolicy/Online/text]",
            bundle: Bundle.framework,
            value: "KeePassium does not collect any personal or analytical data.\nSome features may involve data exchange with external services (on your request and for the sole purpose of making these services available to you). Such an exchange is governed by the privacy policy of the respective service.",
            comment: "A brief summary of the privacy policy (for online mode)")
    }
}
