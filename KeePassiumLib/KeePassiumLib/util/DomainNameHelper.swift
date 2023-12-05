//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import DomainParser

public final class DomainNameHelper {
    public static let shared = DomainNameHelper()

    private let domainParser: DomainParserProtocol
    private init() {
        do {
            domainParser = try DomainParser()
        } catch {
            Diag.error("Failed to init domain parser [message: \(error.localizedDescription)]")
            domainParser = FakeDomainParser()
        }
    }

    public func parse(url: URL) -> ParsedHost? {
        guard let host = url.host else {
            return nil
        }
        return domainParser.parse(host: host)
    }

    public func parse(host: String) -> ParsedHost? {
        return domainParser.parse(host: host)
    }

    public func getMainDomain(url: URL?) -> String? {
        return getMainDomain(host: url?.host)
    }

    public func getMainDomain(host: String?) -> String? {
        if let host,
           let parsedHost = domainParser.parse(host: host),
           let mainDomain = parsedHost.domain
        {
            return mainDomain
        }
        return nil
    }
}

public extension ParsedHost {
    var serviceName: Substring? {
        return domain?.dropLast(publicSuffix.count + 1) 
    }
}
