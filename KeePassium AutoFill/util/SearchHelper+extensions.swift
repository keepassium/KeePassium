//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
    
    var perfectMatch: Entry? {
        guard partialMatch.isEmpty else { return nil }
        guard exactMatch.count == 1,
              let theOnlyGroup = exactMatch.first,
              theOnlyGroup.entries.count == 1,
              let theOnlyScoredEntry = theOnlyGroup.entries.first
        else {
            return nil
        }
        return theOnlyScoredEntry.entry
    }
}

extension SearchHelper {
    
    func find(
        database: Database,
        serviceIdentifiers: [ASCredentialServiceIdentifier]
    ) -> FuzzySearchResults {
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
        let partialMatch = arrangeByGroups(scoredEntries: partialMatchEntries)
        
        let searchResults = FuzzySearchResults(exactMatch: exactMatch, partialMatch: partialMatch)
        return searchResults
    }
    
    private func performSearch(in database: Database, url: String) -> [ScoredEntry] {
        guard let url = URL.from(malformedString: url) else { return [] }
        
        var allEntries = [Entry]()
        guard let rootGroup = database.root else { return [] }
        rootGroup.collectAllEntries(to: &allEntries)
        
        let relevantEntries = allEntries
            .filter { (entry) in
                (entry.parent as? Group2)?.isSearchingEnabled ?? true
            }
            .filter { (entry) in
                !(entry.isDeleted || entry.isHiddenFromSearch)
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
                (entry.parent as? Group2)?.isSearchingEnabled ?? true
            }
            .filter { (entry) in
                !(entry.isDeleted || entry.isHiddenFromSearch)
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
            if url1.guessServiceName() == url2.guessServiceName() {
                return 0.5
            }
        }
        return 0.0
    }
    
    private func getSimilarity(url: URL, entry: Entry) -> Double {
        
        let urlScore = howSimilar(url, with: URL.from(malformedString: entry.resolvedURL))
        
        let guessedServiceName = url.guessServiceName()
        
        var titleScore = 0.0
        var notesScore = 0.0
        
        if let urlHost = url.host {
            if entry.resolvedTitle.localizedCaseInsensitiveContains(urlHost) {
                titleScore = 0.8
            }
            if entry.resolvedNotes.localizedCaseInsensitiveContains(urlHost) {
                notesScore = 0.5
            }
        }
        if let serviceName = guessedServiceName {
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
            with: URL.from(malformedString: entry2.overrideURL))
        let maxScoreSoFar = max(urlScore, titleScore, notesScore, altURLScore)
        if maxScoreSoFar >= 0.5 {
            return maxScoreSoFar
        }
        
        let customFieldValues = entry2.fields
            .filter { !$0.isStandardField }
            .map { $0.resolvedValue }
        
        let urlString = url.absoluteString
        for fieldValue in customFieldValues {
            if fieldValue.localizedCaseInsensitiveContains(urlString) {
                return 1.0
            }
        }
        
        guard let urlHost = url.host else {
            return maxScoreSoFar
        }
        for fieldValue in customFieldValues {
            if fieldValue.localizedCaseInsensitiveContains(urlHost) {
                return 0.5
            }
        }
        
        guard let serviceName = guessedServiceName else {
            return maxScoreSoFar
        }
        for fieldValue in customFieldValues {
            if fieldValue.localizedCaseInsensitiveContains(serviceName) {
                return 0.3
            }
        }
        return maxScoreSoFar
    }
}


fileprivate extension URL {
    private static let genericSLDs = Set<String>(
        ["co", "com", "edu", "ac", "org", "net", "gov", "mil"]
    )
    
    func guessServiceName() -> String? {
        guard let domains = host?.split(separator: ".") else {
            return nil
        }
        let domainLevels = domains.count
        guard domainLevels > 1 else {
            return nil
        }
        let secondLevelDomain = String(domains[domainLevels - 2])
        if !URL.genericSLDs.contains(secondLevelDomain) {
            return secondLevelDomain
        }
        if domainLevels > 2 {
            let thirdLevelDomain = String(domains[domainLevels - 3])
            if thirdLevelDomain.count > 3 {
                return thirdLevelDomain
            } else {
                return domains.suffix(3).joined(separator: ".")
            }
        }
        return domains.suffix(2).joined(separator: ".")
    }
}
