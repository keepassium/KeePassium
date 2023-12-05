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
        let version: String
        let releaseDate: Date
        let items: [Item]
    }

    struct Item: Decodable {
        let title: String
        let type: ItemType
    }

    enum ItemType: Int, Codable {
        case none = 0
        case free = 1
        case premium = 2
    }

    let sections: [Section]
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
