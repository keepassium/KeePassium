//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum URLSimilarity {

    public static func howSimilar(domain: String, with url: URL?) -> Double {
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

    public static func howSimilar(_ url1: URL, parsedHost1: ParsedHost? = nil, with url2: URL?) -> Double {
        guard let url2 else { return 0.0 }

        if url1 == url2 { return 1.0 }

        guard let host1 = url1.host?.localizedLowercase,
              let host2 = url2.host?.localizedLowercase else { return 0.0 }

        let parsedHost1 = parsedHost1 ?? url1.parsedHost
        let parsedHost2 = url2.parsedHost
        
        var isExactHostMatch = false
        var isDomainMatch = false
        if host1 == host2 {
            isExactHostMatch = true
        } else {
            if let mainDomain1 = parsedHost1?.domain,
               let mainDomain2 = parsedHost2?.domain
            {
                isDomainMatch = (mainDomain1 == mainDomain2)
            }
        }

        if isExactHostMatch || isDomainMatch {
            let hostMatchBonus = isExactHostMatch ? 0.1 : 0.0
            var portMismatchPenalty = 0.0
            if let port1 = url1.port,
               let port2 = url2.port,
               port1 != port2
            {
                portMismatchPenalty = -0.2
            }
            guard url2.path.isNotEmpty else { return 0.7 + hostMatchBonus }
            let lowercasePath1 = url1.path.localizedLowercase
            let lowercasePath2 = url2.path.localizedLowercase
            let commonPrefixCount = Double(lowercasePath1.commonPrefix(with: lowercasePath2).count)
            let maxPathCount = Double(max(lowercasePath1.count, lowercasePath2.count))
            let pathSimilarity = commonPrefixCount / maxPathCount

            return min(1.0, 0.7 + hostMatchBonus + portMismatchPenalty + 0.3 * pathSimilarity)
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
}
