//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices
import DomainParser
import KeePassiumLib

struct FuzzySearchResults {
    var exactMatch: SearchResults
    var partialMatch: SearchResults

    var isEmpty: Bool { return exactMatch.isEmpty && partialMatch.isEmpty }

    var perfectMatch: Entry? {
        guard exactMatch.count == 1,
              let theOnlyGroup = exactMatch.first,
              theOnlyGroup.scoredItems.count == 1,
              let theOnlyScoredEntry = theOnlyGroup.scoredItems.first?.item as? Entry
        else {
            return nil
        }
        return theOnlyScoredEntry
    }
}

extension SearchHelper {
    func find(
        database: Database,
        serviceIdentifiers: [ASCredentialServiceIdentifier],
        passkeyRelyingParty: String?
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
                return canSearch && canAutoType
            }
            .filter { entry in
                !(entry.isDeleted || entry.isHiddenFromSearch)
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
                return canSearch && canAutoType
            }
            .filter { entry in
                !(entry.isDeleted || entry.isExpired || entry.isHiddenFromSearch)
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
        guard let host = url?.host?.localizedLowercase else { return 0.0 }

        if host == domain {
            return 1.0
        }
        if let simplifiedURLHost = DomainNameHelper.shared.getMainDomain(host: host),
           domain == simplifiedURLHost
        {
            return 0.95
        }

        return 0.0
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
        guard let url2 = url2 else { return 0.0 }

        if url1 == url2 { return 1.0 }

        var isSimilarHosts = false
        guard let host1 = url1.host?.localizedLowercase,
              let host2 = url2.host?.localizedLowercase else { return 0.0 }

        var parsedHost2: ParsedHost?
        if host1 == host2 {
            isSimilarHosts = true
        } else {
            parsedHost2 = DomainNameHelper.shared.parse(host: host2)
            if let mainDomain1 = parsedHost1?.domain,
               let mainDomain2 = parsedHost2?.domain
            {
                isSimilarHosts = (mainDomain1 == mainDomain2)
            }
        }

        if isSimilarHosts {
            var portMismatchPenalty = 0.0
            if let port1 = url1.port,
               let port2 = url2.port,
               port1 != port2
            {
                portMismatchPenalty = -0.2 
            }
            guard url2.path.isNotEmpty else { return 0.7 }
            let lowercasePath1 = url1.path.localizedLowercase
            let lowercasePath2 = url2.path.localizedLowercase
            let commonPrefixCount = Double(lowercasePath1.commonPrefix(with: lowercasePath2).count)
            let maxPathCount = Double(max(lowercasePath1.count, lowercasePath2.count))
            let pathSimilarity = commonPrefixCount / maxPathCount 

            return 0.7 + portMismatchPenalty + 0.3 * pathSimilarity
        } else {
            if let serviceName1 = parsedHost1?.serviceName,
               let serviceName2 = parsedHost2?.serviceName,
               serviceName1 == serviceName2
            {
                return 0.5
            }
        }
        return 0.0
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
                return canSearch && canAutoType
            }
            .filter { entry in
                !(entry.isDeleted || entry.isExpired || entry.isHiddenFromSearch)
            }
        return relevantEntries.map { ScoredItem(item: $0, similarityScore: 1.0) }
    }
}
