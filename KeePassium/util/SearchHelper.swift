//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

struct ScoredItem {
    let item: DatabaseItem
    let similarityScore: Double
}

struct GroupedItems {
    var group: Group
    var scoredItems: [ScoredItem]
}

typealias SearchResults = [GroupedItems]

final class SearchHelper {
    func findEntries(
        in database: Database,
        searchText: String,
        onlyAutoFillable: Bool = false,
        excludeGroupUUID: UUID? = nil
    ) -> SearchResults {
        return find(
            in: database,
            searchText: searchText,
            flattenGroups: true,
            onlyAutoFillable: onlyAutoFillable,
            excludeGroupUUID: excludeGroupUUID
        )
    }

    func findEntriesAndGroups(
        in database: Database,
        searchText: String,
        onlyAutoFillable: Bool = false,
        excludeGroupUUID: UUID? = nil
    ) -> SearchResults {
        return find(
            in: database,
            searchText: searchText,
            flattenGroups: false,
            onlyAutoFillable: onlyAutoFillable,
            excludeGroupUUID: excludeGroupUUID
        )
    }

    private func find(
        in database: Database,
        searchText: String,
        flattenGroups: Bool,
        onlyAutoFillable: Bool,
        excludeGroupUUID: UUID?
    ) -> SearchResults {
        let settings = Settings.current

        let compareOptions: String.CompareOptions
        if searchText.containsDiacritics() {
            compareOptions = [.caseInsensitive]
        } else {
            compareOptions = [.caseInsensitive, .diacriticInsensitive]
        }

        var fieldScope = SearchQuery.FieldScope()
        if settings.isSearchFieldNames { fieldScope.insert(.fieldNames) }
        if settings.isSearchProtectedValues { fieldScope.insert(.protectedValues) }
        if settings.isSearchPasswords { fieldScope.insert(.passwordField) }

        let query = SearchQuery(
            fieldScope: fieldScope,
            compareOptions: compareOptions,
            excludeGroupUUID: excludeGroupUUID,
            flattenGroups: flattenGroups,
            onlyAutoFillable: onlyAutoFillable,
            text: searchText)
        let scoredItems = performSearch(in: database, query: query)
        let searchResults = arrangeByGroups(scoredItems: scoredItems)
        return searchResults
    }

    private func performSearch(in database: Database, query: SearchQuery) -> [ScoredItem] {
        var foundEntries: [Entry] = []
        var foundGroups: [Group] = []
        let foundCount = database.search(query: query, foundEntries: &foundEntries, foundGroups: &foundGroups)
        Diag.verbose("Found \(foundCount) groups and entries using query")

        if query.onlyAutoFillable {
            let options = Settings.current.autoFillInclusionOptions
            foundEntries = foundEntries.filter { entry in
                let parentGroup2 = entry.parent as? Group2
                let includeFromGroup = parentGroup2?.shouldIncludeInAutoFill(with: options) ?? true
                return includeFromGroup && entry.isAutoFillable(with: options)
            }
        }
        let scoredEntries = foundEntries
            .map { ScoredItem(item: $0, similarityScore: 1.0) }
        let scoredGroups = foundGroups
            .filter { $0.uuid != query.excludeGroupUUID }
            .map { ScoredItem(item: $0, similarityScore: 1.0) }
        return scoredEntries + scoredGroups
    }

    func arrangeByGroups(scoredItems: [ScoredItem]) -> [GroupedItems] {
        var results = [GroupedItems]()
        results.reserveCapacity(scoredItems.count)

        for scoredItem in scoredItems {
            guard let parentGroup = scoredItem.item.parent else {
                assertionFailure()
                continue
            }
            var isInserted = false
            for i in 0..<results.count {
                if results[i].group === parentGroup {
                    results[i].scoredItems.append(scoredItem)
                    isInserted = true
                    break
                }
            }
            if !isInserted {
                let newGroupResult = GroupedItems(
                    group: parentGroup,
                    scoredItems: [scoredItem]
                )
                results.append(newGroupResult)
            }
        }

        return results
    }
}

extension SearchResults {

    mutating func sort(order sortOrder: Settings.GroupSortOrder) {
        sort { sortOrder.compare($0.group, $1.group) }
        for i in 0..<count {
            self[i].scoredItems.sort { scoredItem1, scoredItem2 in
                switch (scoredItem1.item, scoredItem2.item) {
                case (is Group, is Entry):
                    return true
                case (is Entry, is Group):
                    return false
                case let (entry1 as Entry, entry2 as Entry):
                    if scoredItem1.similarityScore == scoredItem2.similarityScore {
                        return sortOrder.compare(entry1, entry2)
                    } else {
                        return (scoredItem2.similarityScore < scoredItem1.similarityScore)
                    }
                case let (group1 as Group, group2 as Group):
                    if scoredItem1.similarityScore == scoredItem2.similarityScore {
                        return sortOrder.compare(group1, group2)
                    } else {
                        return (scoredItem2.similarityScore < scoredItem1.similarityScore)
                    }
                default:
                    assertionFailure("Unexpected item type, must be a Group or Entry")
                    return false
                }
            }
        }
    }
}
