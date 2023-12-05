//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum PassphraseWordlist: Int, Codable, CaseIterable, CustomStringConvertible {
    case effLarge = 0
    case effShort1 = 1
    case effShort2 = 2

    public var description: String {
        switch self {
        case .effLarge:
            return LString.PasswordGenerator.Wordlist.effLargeWordlistTitle
        case .effShort1:
            return String.localizedStringWithFormat(
                LString.PasswordGenerator.Wordlist.effShortWordlistTitleTemplate,
                1
            )
        case .effShort2:
            return String.localizedStringWithFormat(
                LString.PasswordGenerator.Wordlist.effShortWordlistTitleTemplate,
                2
            )
        }
    }

    private var fileName: String {
        switch self {
        case .effLarge:
            return "eff-large-wordlist.txt"
        case .effShort1:
            return "eff-short-wordlist-1.txt"
        case .effShort2:
            return "eff-short-wordlist-2-0.txt"
        }
    }

    public var sourceURL: URL {
        switch self {
        case .effLarge:
            return URL(string: "https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt")!
        case .effShort1:
            return URL(string: "https://www.eff.org/files/2016/09/08/eff_short_wordlist_1.txt")!
        case .effShort2:
            return URL(string: "https://www.eff.org/files/2016/09/08/eff_short_wordlist_2_0.txt")!
        }
    }
}

extension PassphraseWordlist {

    public func load() -> StringSet? {
        Diag.debug("Will load wordlist [fileName: \(fileName)]")
        guard let resourcePath = Bundle.framework.url(
            forResource: fileName,
            withExtension: "",
            subdirectory: ""
        ) else {
            Diag.error("Failed to find wordlist file [fileName: \(fileName)]")
            return nil
        }

        do {
            let data = try String(contentsOf: resourcePath)
            var stringSet = StringSet()
            data.enumerateLines { line, _ in
                stringSet.insert(line)
            }
            Diag.debug("Wordlist loaded successfully")
            return stringSet
        } catch {
            Diag.error("Failed to load wordlist [message: \(error.localizedDescription)]")
            return nil
        }
    }
}


extension LString.PasswordGenerator {
    enum Wordlist {
        public static let effLargeWordlistTitle = NSLocalizedString(
            "[PasswordGenerator/Wordlist/EFFLarge/title]",
            bundle: Bundle.framework,
            value: "EFF Large Wordlist (7776 words)",
            comment: "Name of a wordlist for passphrase generator. `EFF` is an organization name."
        )
        public static let effShortWordlistTitleTemplate = NSLocalizedString(
            "[PasswordGenerator/Wordlist/EFFShort/title]",
            bundle: Bundle.framework,
            value: "EFF Short Wordlist #%d (1296 words)",
            comment: "Name of a wordlist for passphrase generator. `EFF` is an organization name."
        )
    }
}
