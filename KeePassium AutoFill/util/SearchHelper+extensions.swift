//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices
import DomainParser
import KeePassiumLib

extension SearchHelper {
    func find(
        database: Database,
        serviceIdentifiers: [ASCredentialServiceIdentifier],
        passkeyRelyingParty: String?,
        allowOnly itemKind: AutoFillItemKind?
    ) -> FuzzySearchResults {
        var relevantEntries = [ScoredItem]()
        if let passkeyRelyingParty {
            relevantEntries = performSearch(in: database, relyingParty: passkeyRelyingParty)
        } else {
            for si in serviceIdentifiers {
                switch si.type {
                case .domain:
                    let partialResults = performSearch(in: database, domain: si.identifier)
                    relevantEntries.append(contentsOf: partialResults)
                case .URL:
                    let partialResults = performSearch(in: database, url: si.identifier)
                    relevantEntries.append(contentsOf: partialResults)
                @unknown default:
                    assertionFailure()
                }
            }
        }
        if let itemKind {
            relevantEntries = relevantEntries.filter { itemKind.matches($0.item) }
        }
        let exactMatchEntries = relevantEntries.filter { $0.similarityScore >= 0.99 }
        let partialMatchEntries = relevantEntries.filter { $0.similarityScore < 0.99 }
        let exactMatch = arrangeByGroups(scoredItems: exactMatchEntries)
        let partialMatch = arrangeByGroups(scoredItems: partialMatchEntries)

        let searchResults = FuzzySearchResults(exactMatch: exactMatch, partialMatch: partialMatch)
        return searchResults
    }
}

extension SearchHelper {

    private func performSearch(in database: Database, url: String) -> [ScoredItem] {
        guard let url = URL.from(malformedString: url) else { return [] }
        let parsedHost = DomainNameHelper.shared.parse(url: url) 

        var allEntries = [Entry]()
        guard let rootGroup = database.root else { return [] }
        rootGroup.collectAllEntries(to: &allEntries)

        let relevantEntries = allEntries
            .filter { entry in
                let parent2 = entry.parent as? Group2
                let canSearch = parent2?.resolvingIsSearchingEnabled() ?? true
                let canAutoType = parent2?.resolvingIsAutoTypeEnabled() ?? true
                return canSearch && canAutoType && entry.isAutoFillable
            }
            .map { entry in
                return ScoredItem(
                    item: entry,
                    similarityScore: getSimilarity(url: url, parsedHost: parsedHost, entry: entry)
                )
            }
            .filter { $0.similarityScore > 0.0 }
            .sorted { $0.similarityScore > $1.similarityScore }
        Diag.verbose("Found \(relevantEntries.count) relevant entries [among \(allEntries.count)]")
        return relevantEntries
    }

    private func performSearch(in database: Database, domain: String) -> [ScoredItem] {
        var allEntries = [Entry]()
        guard let rootGroup = database.root else { return [] }
        rootGroup.collectAllEntries(to: &allEntries)

        let mainDomain = DomainNameHelper.shared.getMainDomain(host: domain) ?? domain
        let compareOptions: String.CompareOptions = [.caseInsensitive]

        let relevantEntries = allEntries
            .filter { entry in
                let parent2 = entry.parent as? Group2
                let canSearch = parent2?.resolvingIsSearchingEnabled() ?? true
                let canAutoType = parent2?.resolvingIsAutoTypeEnabled() ?? true
                return canSearch && canAutoType && entry.isAutoFillable
            }
            .map { entry in
                return ScoredItem(
                    item: entry,
                    similarityScore: getSimilarity(
                        domain: mainDomain,
                        entry: entry,
                        options: compareOptions
                    )
                )
            }
            .filter { $0.similarityScore > 0.0 }
            .sorted { $0.similarityScore > $1.similarityScore }
        Diag.verbose("Found \(relevantEntries.count) relevant entries [among \(allEntries.count)]")
        return relevantEntries
    }

    private func howSimilar(domain: String, with url: URL?) -> Double {
        URLSimilarity.howSimilar(domain: domain, with: url)
    }

    private func getSimilarity(domain: String, entry: Entry, options: String.CompareOptions) -> Double {
        let urlScore = howSimilar(domain: domain, with: URL.from(malformedString: entry.resolvedURL))
        let titleScore = entry.resolvedTitle.localizedContains(domain, options: options) ? 0.8 : 0.0
        let notesScore = entry.resolvedNotes.localizedContains(domain, options: options) ? 0.5 : 0.0

        if let entry2 = entry as? Entry2 {
            let altURLScore = howSimilar(
                domain: domain,
                with: URL.from(malformedString: entry2.overrideURL))
            let maxScoreSoFar = max(urlScore, titleScore, notesScore, altURLScore)
            if maxScoreSoFar >= 0.5 {
                return maxScoreSoFar
            }

            let extraFieldScores: [Double] = entry2.fields
                .filter { !$0.isStandardField }
                .map { field in
                    return field.value.localizedContains(domain, options: options) ? 0.5 : 0.0
            }
            return max(maxScoreSoFar, extraFieldScores.max() ?? 0.0)
        } else {
            return max(urlScore, titleScore, notesScore)
        }
    }

    private func howSimilar(
        _ url1: URL,
        parsedHost parsedHost1: ParsedHost?,
        with url2: URL?
    ) -> Double {
        URLSimilarity.howSimilar(url1, parsedHost1: parsedHost1, with: url2)
    }

    private func getSimilarity(url: URL, parsedHost: ParsedHost?, entry: Entry) -> Double {

        let urlScore = howSimilar(
            url,
            parsedHost: parsedHost,
            with: URL.from(malformedString: entry.resolvedURL)
        )

        var titleScore = 0.0
        var notesScore = 0.0

        if let simplifiedHost = parsedHost?.domain ?? url.host {
            if entry.resolvedTitle.localizedCaseInsensitiveContains(simplifiedHost) {
                titleScore = 0.8
            }
            if entry.resolvedNotes.localizedCaseInsensitiveContains(simplifiedHost) {
                notesScore = 0.5
            }
        }

        let serviceName = parsedHost?.serviceName
        if let serviceName {
            if entry.resolvedTitle.localizedCaseInsensitiveContains(serviceName) {
                titleScore = max(titleScore, 0.5)
            }
            if entry.resolvedNotes.localizedCaseInsensitiveContains(serviceName) {
                notesScore = max(notesScore, 0.3)
            }
        }

        guard let entry2 = entry as? Entry2 else {
            return max(urlScore, titleScore, notesScore)
        }

        let altURLScore = howSimilar(
            url,
            parsedHost: parsedHost,
            with: URL.from(malformedString: entry2.overrideURL))
        let maxScoreSoFar = max(urlScore, titleScore, notesScore, altURLScore)

        let customFieldValues = entry2.fields
            .filter { !$0.isStandardField }
            .map { $0.resolvedValue }

        let urlString = url.absoluteString
        for fieldValue in customFieldValues {
            if fieldValue.localizedCaseInsensitiveContains(urlString) {
                return 1.0
            }
        }

        guard let mainDomain = parsedHost?.domain else {
            return maxScoreSoFar
        }
        for fieldValue in customFieldValues {
            if fieldValue == mainDomain {
                return max(0.95, maxScoreSoFar)
            }
            if fieldValue.localizedCaseInsensitiveContains(mainDomain) {
                return max(0.5, maxScoreSoFar)
            }
        }

        if maxScoreSoFar > 0.3 {
            return maxScoreSoFar
        }

        if let serviceName {
            for fieldValue in customFieldValues {
                if fieldValue.localizedCaseInsensitiveContains(serviceName) {
                    return max(0.3, maxScoreSoFar)
                }
            }
        }
        return maxScoreSoFar
    }
}

extension SearchHelper {
    private func performSearch(in database: Database, relyingParty: String) -> [ScoredItem] {
        guard let rootGroup = database.root else { return [] }

        var relevantEntries = [Entry]()
        rootGroup.applyToAllChildren(
            groupHandler: nil,
            entryHandler: { entry in
                if relyingParty == entry.getField(EntryField.passkeyRelyingParty)?.resolvedValue {
                    relevantEntries.append(entry)
                }
            }
        )

        relevantEntries = relevantEntries
            .filter { entry in
                let parent2 = entry.parent as? Group2
                let canSearch = parent2?.resolvingIsSearchingEnabled() ?? true
                let canAutoType = parent2?.resolvingIsAutoTypeEnabled() ?? true
                return canSearch && canAutoType && entry.isAutoFillable
            }
        return relevantEntries.map { ScoredItem(item: $0, similarityScore: 1.0) }
    }
}
