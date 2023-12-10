//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

struct AppHistory: Decodable {
    fileprivate static let fileName = "ChangeLog"

    struct Section: Decodable {
        var version: String
        var releaseDate: Date
        var items: [Item]
    }

    struct Item: Decodable {
        enum ItemType: Int, Codable {
            case none = 0
            case free = 1
            case premium = 2

            static let `default`: Self = .free
        }

        enum Edition: String, Decodable, CaseIterable {
            case free
            case pro
            case org
        }

        // swiftlint:disable type_name
        enum OS: String, Decodable, CaseIterable {
            case ios
            case macos
        }
        // swiftlint:enable type_name

        enum Change: String, CaseIterable, CustomStringConvertible {
            case info = "Info"
            case fix = "Fixed"
            case improvement = "Improved"
            case feature = "Added"
            case change = "Changed"
            case refinement = "Refined"

            static let `default`: Self = .info

            var description: String { rawValue }

            var symbolName: SymbolName {
                switch self {
                case .info:
                    return .infoCircle
                case .feature:
                    return .plusCircleFill
                case .fix:
                    return .antCircle
                case .improvement, .refinement:
                    return .arrowUpCircleFill
                case .change:
                    return .infoCircleFill
                }
            }

            var tintColor: UIColor {
                switch self {
                case .feature:
                    return .systemGreen
                case .fix:
                    return .systemRed
                case .improvement, .refinement, .change, .info:
                    return .systemBlue
                }
            }
        }

        let title: String
        let type: ItemType
        let credits: [String]
        let edition: [Edition]
        let change: Change
        let os: [OS]

        enum CodingKeys: String, CodingKey {
            case title, type, credits, edition, os
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let array = { key -> [String]? in
                try container.decodeIfPresent(String.self, forKey: key)?
                    .components(separatedBy: ",")
                    .map({ $0.trimmingCharacters(in: .whitespaces) })
                    .filter({ !$0.isEmpty })
            }

            type = try container.decodeIfPresent(ItemType.self, forKey: .type) ?? .default
            os = try array(.os)?.compactMap({ OS(rawValue: $0) }) ?? OS.allCases
            edition = try array(.edition)?.compactMap({ Edition(rawValue: $0) }) ?? Edition.allCases
            credits = try array(.credits) ?? []

            let title = try container.decode(String.self, forKey: .title)
            let change = Change.allCases.first(where: { title.hasPrefix($0.rawValue) })
            self.change = change ?? .default

            if let change = change {
                self.title = title.dropFirst(change.rawValue.count + 1).trimmingCharacters(in: .whitespaces)
            } else {
                self.title = title
            }
        }
    }

    var sections: [Section]
}

extension AppHistory {

    public static func load(completion: @escaping ((AppHistory?) -> Void)) {
        DispatchQueue.global(qos: .userInitiated).async {
            loadInBackground(completion: completion)
        }
    }

    private static func loadInBackground(completion: @escaping ((AppHistory?) -> Void)) {
        dispatchPrecondition(condition: .notOnQueue(.main))

        let url = Bundle.main.url(
            forResource: AppHistory.fileName,
            withExtension: "json",
            subdirectory: "")
        guard let fileURL = url else {
            Diag.error("Failed to find app history file")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        do {
            let fileContents = try Data(contentsOf: fileURL)
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .iso8601
            let appHistory = try jsonDecoder.decode(AppHistory.self, from: fileContents)
            DispatchQueue.main.async {
                completion(appHistory)
            }
        } catch {
            Diag.error("Failed to load app history file [reason: \(error.localizedDescription)]")
            DispatchQueue.main.async { completion(nil) }
        }
    }

    public func versionOnDate(_ date: Date) -> String? {
        let sortedSections = sections.sorted(by: { $0.releaseDate < $1.releaseDate })
        let matchingSection = sortedSections.last(where: { $0.releaseDate <= date })
        return matchingSection?.version
    }
}
