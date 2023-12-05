//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

struct ScoredEntry {
    let entry: Entry
    let similarityScore: Double
}
struct GroupedEntries {
    var group: Group
    var entries: [ScoredEntry]
}

typealias SearchResults = [GroupedEntries]

class SearchHelper {

    func find(database: Database, searchText: String) -> SearchResults {
        let settings = Settings.current
        let words = searchText.split(separator: " " as Character)

        let compareOptions: String.CompareOptions
        if searchText.containsDiacritics() {
            compareOptions = [.caseInsensitive]
        } else {
            compareOptions = [.caseInsensitive, .diacriticInsensitive]
        }

        let query = SearchQuery(
            includeSubgroups: true,
            includeDeleted: false,
            includeFieldNames: settings.isSearchFieldNames,
            includeProtectedValues: settings.isSearchProtectedValues,
            includePasswords: settings.isSearchPasswords,
            compareOptions: compareOptions,
            text: searchText,
            textWords: words)
        let scoredEntries = performSearch(in: database, query: query)
            .filter {
                !$0.entry.isHiddenFromSearch
            }
        let searchResults = arrangeByGroups(scoredEntries: scoredEntries)
        return searchResults
    }

    private func performSearch(in database: Database, query: SearchQuery) -> [ScoredEntry] {
        var foundEntries: [Entry] = []
        let foundCount = database.search(query: query, result: &foundEntries)
        Diag.verbose("Found \(foundCount) entries using query")

        let scoredEntries = foundEntries.map { entry in
            return ScoredEntry(entry: entry, similarityScore: 1.0)
        }
        return scoredEntries
    }

    public func arrangeByGroups(scoredEntries: [ScoredEntry]) -> [GroupedEntries] {
        var results = [GroupedEntries]()
        results.reserveCapacity(scoredEntries.count)

        for scoredEntry in scoredEntries {
            guard let parentGroup = scoredEntry.entry.parent else { assertionFailure(); return [] }
            var isInserted = false
            for i in 0..<results.count {
                if results[i].group === parentGroup {
                    results[i].entries.append(scoredEntry)
                    isInserted = true
                    break
                }
            }
            if !isInserted {
                let newGroupResult = GroupedEntries(group: parentGroup, entries: [scoredEntry])
                results.append(newGroupResult)
            }
        }
        return results
    }
}

extension SearchResults {

    mutating public func sort(order sortOrder: Settings.GroupSortOrder) {
        sort { sortOrder.compare($0.group, $1.group) }
        for i in 0..<count {
            self[i].entries.sort { scoredEntry1, scoredEntry2 in
                if scoredEntry1.similarityScore == scoredEntry2.similarityScore {
                    return sortOrder.compare(scoredEntry1.entry, scoredEntry2.entry)
                } else {
                    return (scoredEntry2.similarityScore < scoredEntry1.similarityScore)
                }
            }
        }
    }
}
