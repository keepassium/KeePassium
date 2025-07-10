//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension LString {
    public static let activateAutoFillAction = NSLocalizedString(
        "[Settings/AutoFill/Activate/action]",
        value: "Activate AutoFill",
        comment: "Action that opens system settings or instructions")
    public static let autoFillSetupGuideTitle = NSLocalizedString(
        "[Settings/AutoFill/Setup Guide/title]",
        value: "AutoFill Setup Guide",
        comment: "Title of a help article on how to activate AutoFill.")
    public static let autoFillActivationDescription = NSLocalizedString(
        "[Settings/AutoFill/Activate/description]",
        value: "Before first use, you need to activate AutoFill in system settings.",
        comment: "Description for the AutoFill setup instructions")
    public static let autoFillUnavailableInIntuneDescription = NSLocalizedString(
        "[Settings/AutoFill/UnavailableInIntune/description]",
        value: "AutoFill is not available in KeePassium for Intune.",
        comment: "")

    public static let quickAutoFillDescription = NSLocalizedString(
        "[QuickAutoFill/description]",
        value: "Quick AutoFill shows relevant entries right next to the password field, without opening KeePassium.",
        comment: "Description of the Quick AutoFill feature.")

    public static let automaticSearchTitle = NSLocalizedString(
        "[Settings/AutoSearch/title]",
        value: "Automatic search",
        comment: "Title of a section in settings")
    public static let autoFillPerfectMatchTitle = NSLocalizedString(
        "[Settings/AutoFill/UsePerfectMatch/title]",
        value: "Fill-In Perfect Result Automatically",
        comment: "Title of a yes/no setting: automatically use the single best match found by AutoFill search")
    public static let autoFillPerfectMatchDescription = NSLocalizedString(
        "[Settings/AutoFill/UsePerfectMatch/description]",
        value: "When AutoFill finds only one, perfectly matching, entry – this entry will be pasted automatically.",
        comment: "Description of the 'Fill-In Perfect Result Automatically' setting")

    public static let oneTimePasswordsTitle = NSLocalizedString(
        "[Settings/OTP/title]",
        value: "One-time passwords",
        comment: "Title of a section in settings")
    public static let autoFillCopyOTPtoClipboardTitle = NSLocalizedString(
        "[Settings/AutoFill/CopyOTP/title]",
        value: "Copy OTP to Clipboard",
        comment: "Title of a yes/no setting: copy one-time password to clipboard when using AutoFill")
    public static let autoFillCopyOTPtoClipboardDescription = NSLocalizedString(
        "[Settings/AutoFill/CopyOTP/Description]",
        value: "When AutoFill inserts the username and password, it can also copy the one-time password (OTP) for you.",
        comment: "Description of the 'Copy OTP to Clipboard' setting")
}
