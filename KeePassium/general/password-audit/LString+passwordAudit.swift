//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

// swiftlint:disable line_length
extension LString {
    static let actionExcludeFromAudit = NSLocalizedString(
        "[PasswordAudit/Action/Exclude]",
        value: "Exclude From Audit",
        comment: "Action to skip selected item/items in future password audits.")
    static let titlePasswordAudit = NSLocalizedString(
        "[PasswordAudit/title]",
        value: "Password Audit",
        comment: "Title of a screen to check which passwords are known to be compromised.")
    static let passwordAuditIntroTemplate = NSLocalizedString(
        "[PasswordAudit/Intro/text]",
        value: """
Password audit checks your passwords against an online database of leaked passwords in a secure and private way.

KeePassium will send information calculated from your passwords — a kind of a partial checksum — to the [Have I Been Pwned](https://haveibeenpwned.com) service. \
The service will return detailed information about compromised passwords with similar checksums. \
The app will then compare the detailed checksums locally on the device and detect which of your passwords are at risk.

Your actual passwords are never shared with the online service.
[Learn more…](%@)
""",
        comment: "Description of the Password Audit function.")
    static let actionStartPasswordAudit = NSLocalizedString(
        "[PasswordAudit/Start/action]",
        value: "Start Audit",
        comment: "Action/button: intiate password audit")
    static let confirmExcludeSelectionFromAudit = NSLocalizedString(
        "[Selection/ExcludeFromAudit/confirmation]",
        value: "Exclude selection from password audit?",
        comment: "Title of the confirmation dialog for `Exclude from audit` action for several items")
    static let confirmDeleteSelection = NSLocalizedString(
        "[Selection/Delete/confirmation]",
        value: "Delete selection?",
        comment: "Title of the confirmation dialog for `Delete` action for several items")
    static let statusAuditingPasswords = NSLocalizedString(
        "[PasswordAudit/Auditing/status]",
        value: "Auditing passwords",
        comment: "Status message: password audit in progress")
    static let titleCompromisedPasswords = NSLocalizedString(
        "[PasswordAudit/Results/title]",
        value: "Compromised Passwords",
        comment: "Title of a list with passwords that are known to have been exposed in online breaches.")
    static let exposureCountDescription = NSLocalizedString(
        "[PasswordAudit/ExposureCount/description]",
        value: "The number shows how many times the password has been found in known data leaks.",
        comment: "Description of the password audit results, where a number appears next to each password.")

    static let titleAllPasswordsAreSecure = NSLocalizedString(
        "[PasswordAudit/Results/allGood]",
        value: "Good news! None of your passwords have appeared in known data leaks.",
        comment: "Result of a password audit.")
}

extension LString.Error {
    static let passwordAuditErrorTemplate = NSLocalizedString(
        "[PasswordAudit/Error/text]",
        value: "An error occured while communicating with the HIBP service. %@",
        comment: "Error message after a failed password audit request [message: String].")
}
// swiftlint:enable line_length
