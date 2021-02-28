//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


import KeePassiumLib
import AuthenticationServices


struct FuzzySearchResults {
    var exactMatch: SearchResults
    var partialMatch: SearchResults
    
    var isEmpty: Bool { return exactMatch.isEmpty && partialMatch.isEmpty }
    
    var hasPerfectMatch: Bool {
        guard partialMatch.isEmpty && (exactMatch.count == 1) else { return false }
        let firstGroup = exactMatch.first!
        return firstGroup.entries.count == 1
    }
}

extension SearchHelper {
    
    func find(
        database: Database,
        serviceIdentifiers: [ASCredentialServiceIdentifier]
        ) -> FuzzySearchResults
    {
        var relevantEntries = [ScoredEntry]()
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
        
        let exactMatchEntries = relevantEntries.filter { $0.similarityScore >= 0.99 }
        let partialMatchEntries = relevantEntries.filter { $0.similarityScore < 0.99 }
        let exactMatch = arrangeByGroups(scoredEntries: exactMatchEntries)
            .excludingNonAutoFillableEntries()
        let partialMatch = arrangeByGroups(scoredEntries: partialMatchEntries)
            .excludingNonAutoFillableEntries()
        
        let searchResults = FuzzySearchResults(exactMatch: exactMatch, partialMatch: partialMatch)
        return searchResults
    }
    
    private func performSearch(in database: Database, url: String) -> [ScoredEntry] {
        guard let url = URL.guessFrom(malformedString: url) else { return [] }
        
        var allEntries = [Entry]()
        guard let rootGroup = database.root else { return [] }
        rootGroup.collectAllEntries(to: &allEntries)
        
        let relevantEntries = allEntries
            .filter { (entry) in
                if let group2 = entry.parent as? Group2 {
                    return group2.isSearchingEnabled ?? true
                } else {
                    return !entry.isDeleted
                }
            }
            .map { (entry) in
                return ScoredEntry(
                    entry: entry,
                    similarityScore: getSimilarity(url: url, entry: entry)
                )
            }
            .filter { $0.similarityScore > 0.0 }
            .sorted { $0.similarityScore > $1.similarityScore }
        Diag.verbose("Found \(relevantEntries.count) relevant entries [among \(allEntries.count)]")
        return relevantEntries
    }
    
    private func performSearch(in database: Database, domain: String) -> [ScoredEntry] {
        var allEntries = [Entry]()
        guard let rootGroup = database.root else { return [] }
        rootGroup.collectAllEntries(to: &allEntries)
        
        let compareOptions: String.CompareOptions = [.caseInsensitive]
        
        let relevantEntries = allEntries
            .filter { (entry) in
                if let group2 = entry.parent as? Group2 {
                    return group2.isSearchingEnabled ?? true
                } else {
                    return !entry.isDeleted
                }
            }
            .map { (entry) in
                return ScoredEntry(
                    entry: entry,
                    similarityScore: getSimilarity(
                        domain: domain,
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
        if host.hasSuffix("." + domain) {
            return 0.9
        }
        return 0.0
    }
    
    private func getSimilarity(domain: String, entry: Entry, options: String.CompareOptions) -> Double {
        let urlScore = howSimilar(domain: domain, with: URL.guessFrom(malformedString: entry.resolvedURL))
        let titleScore = entry.resolvedTitle.localizedContains(domain, options: options) ? 0.8 : 0.0
        let notesScore = entry.resolvedNotes.localizedContains(domain, options: options) ? 0.5 : 0.0
        
        if let entry2 = entry as? Entry2 {
            let altURLScore = howSimilar(
                domain: domain,
                with: URL.guessFrom(malformedString: entry2.overrideURL))
            let maxScoreSoFar = max(urlScore, titleScore, notesScore, altURLScore)
            if maxScoreSoFar >= 0.5 {
                return maxScoreSoFar
            }
            
            let extraFieldScores: [Double] = entry2.fields
                .filter { !$0.isStandardField }
                .map { (field) in
                    return field.value.localizedContains(domain, options: options) ? 0.5 : 0.0
            }
            return max(maxScoreSoFar, extraFieldScores.max() ?? 0.0)
        } else {
            return max(urlScore, titleScore, notesScore)
        }
    }
    
    
    private func howSimilar(_ url1: URL, with url2: URL?) -> Double {
        guard let url2 = url2 else { return 0.0 }
        
        if url1 == url2 { return 1.0 }
        
        guard let host1 = url1.host?.localizedLowercase,
            let host2 = url2.host?.localizedLowercase else { return 0.0 }
        if host1 == host2 {
            
            guard url2.path.isNotEmpty else { return 0.7 }
            let lowercasePath1 = url1.path.localizedLowercase
            let lowercasePath2 = url2.path.localizedLowercase
            let commonPrefixCount = Double(lowercasePath1.commonPrefix(with: lowercasePath2).count)
            let maxPathCount = Double(max(lowercasePath1.count, lowercasePath2.count))
            let pathSimilarity = commonPrefixCount / maxPathCount 
            return 0.7 + 0.3 * pathSimilarity 
        } else {
            if url1.domain2 == url2.domain2 {
                return 0.5
            }
        }
        return 0.0
    }
    
    private func getSimilarity(url: URL, entry: Entry) -> Double {
        
        let urlScore = howSimilar(url, with: URL.guessFrom(malformedString: entry.resolvedURL))
        let titleScore: Double
        let notesScore: Double
        
        if let urlHost = url.host, let urlDomain2 = url.domain2 {
            if entry.resolvedTitle.localizedCaseInsensitiveContains(urlHost) {
                titleScore = 0.8
            } else if entry.resolvedTitle.localizedCaseInsensitiveContains(urlDomain2) {
                titleScore = 0.5
            } else {
                titleScore = 0.0
            }
            if entry.resolvedNotes.localizedCaseInsensitiveContains(urlHost) {
                notesScore = 0.5
            } else if entry.resolvedNotes.localizedCaseInsensitiveContains(urlDomain2) {
                notesScore = 0.3
            } else {
                notesScore = 0.0
            }
        } else {
            titleScore = 0.0
            notesScore = 0.0
        }
        
        if let entry2 = entry as? Entry2 {
            let altURLScore = howSimilar(
                url,
                with: URL.guessFrom(malformedString: entry2.overrideURL))
            let maxScoreSoFar = max(urlScore, titleScore, notesScore, altURLScore)
            if maxScoreSoFar >= 0.5 {
                return maxScoreSoFar
            }
            
            let urlString = url.absoluteString
            guard let urlHost = url.host,
                let urlDomain2 = url.domain2 else { return maxScoreSoFar }
            let extraFieldScores: [Double] = entry2.fields
                .filter { !$0.isStandardField }
                .map { (field) in
                    if field.value.localizedCaseInsensitiveContains(urlString) {
                        return 1.0
                    } else if field.value.localizedCaseInsensitiveContains(urlHost) {
                        return 0.5
                    } else if field.value.localizedCaseInsensitiveContains(urlDomain2) {
                        return 0.3
                    } else {
                        return 0.0
                    }
            }
            return max(maxScoreSoFar, extraFieldScores.max() ?? 0.0)
        } else {
            return max(urlScore, titleScore, notesScore)
        }
    }
}

fileprivate extension URL {
    static func guessFrom(malformedString string: String?) -> URL? {
        guard let string = string else { return nil }
        
        if let wellFormedURL = URL(string: string), let _ = wellFormedURL.scheme {
            return wellFormedURL
        }
        guard let fakeSchemeURL = URL(string: "https://" + string),
            let _ = fakeSchemeURL.host else {
                return nil
        }
        return fakeSchemeURL
    }
}

extension SearchResults {
    func excludingNonAutoFillableEntries() -> SearchResults {
        let excludeFromAutoFillCustomDataKey = "BrowserHideEntry"
        
        var result = SearchResults()
        self.forEach{ groupedEntries in
            let filteredEntries = groupedEntries.entries.filter {
                guard let entry2 = $0.entry as? Entry2,
                    let valueItem = entry2.customData[excludeFromAutoFillCustomDataKey] else
                {
                    return true
                }
                let isHidden = Bool(string: valueItem.value)
                return !isHidden
            }
            if filteredEntries.count > 0 {
                result.append(GroupedEntries(group: groupedEntries.group, entries: filteredEntries))
            }
        }
        return result
    }
}
