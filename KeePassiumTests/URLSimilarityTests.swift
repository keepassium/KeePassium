//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

@testable import KeePassiumLib
import XCTest

final class URLSimilarityTests: XCTestCase {

    // MARK: - howSimilar(domain:with:)

    func testDomainExactHostMatch() {
        let url = URL(string: "https://mycompany.com")!
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: url), 1.0)
    }

    func testDomainSubdomainMatch() {
        let url = URL(string: "https://mail.mycompany.com")!
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: url), 0.95)
    }

    func testDomainNoMatch() {
        let url = URL(string: "https://example.com")!
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: url), 0.0)
    }

    func testDomainNilURL() {
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: nil), 0.0)
    }

    func testDomainURLWithoutHost() {
        let url = URL(string: "file:///path/to/file")!
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: url), 0.0)
    }

    func testDomainCaseInsensitive() {
        let url = URL(string: "https://Mycompany.COM")!
        XCTAssertEqual(URLSimilarity.howSimilar(domain: "mycompany.com", with: url), 1.0)
    }

    // MARK: - howSimilar(_:with:) — Exact host match vs domain-only match

    func testExactHostMatchScoresHigherThanDomainOnlyMatch() {
        let searchURL = URL(string: "https://mail.mycompany.com")!
        let exactMatchURL = URL(string: "https://mail.mycompany.com")!
        let domainOnlyMatchURL = URL(string: "https://xyz.mycompany.com")!

        let exactScore = URLSimilarity.howSimilar(searchURL, with: exactMatchURL)
        let domainOnlyScore = URLSimilarity.howSimilar(searchURL, with: domainOnlyMatchURL)

        XCTAssertGreaterThan(
            exactScore,
            domainOnlyScore,
            "Exact host match (\(exactScore)) should score higher than domain-only match (\(domainOnlyScore))"
        )
    }

    func testExactHostMatchWithoutPath() {
        let url1 = URL(string: "https://mail.mycompany.com")!
        let url2 = URL(string: "https://mail.mycompany.com")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 1.0, "Identical URLs should score 1.0")
    }

    func testDomainOnlyMatchWithoutPath() {
        let url1 = URL(string: "https://mail.mycompany.com")!
        let url2 = URL(string: "https://xyz.mycompany.com")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 0.7, accuracy: 0.001, "Domain-only match without path should score 0.7")
    }

    func testExactHostMatchBaseScore() {
        let url1 = URL(string: "https://mail.mycompany.com")!
        let url2 = URL(string: "https://mail.mycompany.com/different/path")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 0.8, accuracy: 0.001, "Exact host match should have base score ~0.8")
    }

    // MARK: - howSimilar(_:with:) — Exact URL match

    func testExactURLMatch() {
        let url = URL(string: "https://example.com/path/to/page")!
        XCTAssertEqual(URLSimilarity.howSimilar(url, with: url), 1.0)
    }

    // MARK: - howSimilar(_:with:) — nil and missing host

    func testNilURL2() {
        let url1 = URL(string: "https://example.com")!
        XCTAssertEqual(URLSimilarity.howSimilar(url1, with: nil), 0.0)
    }

    // MARK: - howSimilar(_:with:) — Same host, path similarity

    func testSameHostMatchingPaths() {
        let url1 = URL(string: "https://example.com/app/login")!
        let url2 = URL(string: "https://example.com/app/login")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 1.0, "Same host with identical paths should score 1.0")
    }

    func testSameHostDifferentPaths() {
        let url1 = URL(string: "https://example.com/app/login")!
        let url2 = URL(string: "https://example.com/other/page")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertGreaterThan(score, 0.7, "Same host with different paths should score > 0.7 (has path overlap from /)")
        XCTAssertLessThan(score, 1.0, "Same host with different paths should score < 1.0")
    }

    func testSameHostPartialPathOverlap() {
        let url1 = URL(string: "https://example.com/app/login")!
        let url2 = URL(string: "https://example.com/app/settings")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertGreaterThan(score, 0.8, "Same host with partially overlapping paths should score > 0.8")
    }

    // MARK: - howSimilar(_:with:) — Port mismatch

    func testPortMismatchPenalty() {
        let url1 = URL(string: "https://example.com:443/path")!
        let url2 = URL(string: "https://example.com:8443/path")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        let urlWithoutPort = URL(string: "https://example.com/path")!
        let scoreWithoutPort = URLSimilarity.howSimilar(url1, with: urlWithoutPort)

        XCTAssertLessThan(
            score,
            scoreWithoutPort,
            "Port mismatch should reduce the score"
        )
    }

    // MARK: - howSimilar(_:with:) — Service name match

    func testServiceNameMatch() {
        let url1 = URL(string: "https://mycompany.com")!
        let url2 = URL(string: "https://mycompany.ch")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 0.5, "Same service name with different TLD should score 0.5")
    }

    func testNoMatch() {
        let url1 = URL(string: "https://example.com")!
        let url2 = URL(string: "https://different.org")!

        let score = URLSimilarity.howSimilar(url1, with: url2)
        XCTAssertEqual(score, 0.0, "Completely different domains should score 0.0")
    }

    // MARK: - Regression: the original bug scenario

    func testSubdomainPreference() {
        let searchURL = URL(string: "https://mail.mycompany.com")!

        let entryURLExact = URL(string: "https://mail.mycompany.com")!
        let entryURLOtherSubdomain = URL(string: "https://xyz.mycompany.com")!
        let entryURLBaseDomain = URL(string: "https://mycompany.com")!

        let scoreExact = URLSimilarity.howSimilar(searchURL, with: entryURLExact)
        let scoreOtherSubdomain = URLSimilarity.howSimilar(searchURL, with: entryURLOtherSubdomain)
        let scoreBaseDomain = URLSimilarity.howSimilar(searchURL, with: entryURLBaseDomain)

        XCTAssertGreaterThan(
            scoreExact,
            scoreOtherSubdomain,
            "mail.mycompany.com should rank higher than xyz.mycompany.com when searching for mail.mycompany.com"
        )
        XCTAssertGreaterThan(
            scoreExact,
            scoreBaseDomain,
            "mail.mycompany.com should rank higher than mycompany.com when searching for mail.mycompany.com"
        )
        XCTAssertGreaterThanOrEqual(
            scoreBaseDomain,
            scoreOtherSubdomain,
            "mycompany.com should rank at least as high as xyz.mycompany.com"
        )
    }
}
