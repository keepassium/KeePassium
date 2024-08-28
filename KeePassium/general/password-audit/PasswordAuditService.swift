//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import CryptoKit
import Foundation
import KeePassiumLib

protocol PasswordAuditServiceDelegate: AnyObject {
    func progressDidUpdate(progress: ProgressEx)
}

final class PasswordAuditService {


    typealias PasswordAuditResult = Result<[PasswordAudit], PasswordAuditError>


    enum PasswordAuditError: LocalizedError {
        case canceled
        case requestError(HIBPService.PasswordRangeError)
        var errorDescription: String? {
            switch self {
            case .canceled:
                return "Cancelled"
            case .requestError(let rangeError):
                return rangeError.errorDescription
            }
        }
    }


    struct PasswordAudit {
        let entry: Entry
        let count: Int
    }


    private let hibpService: HIBPService
    private var entries: [Entry]

    weak var delegate: PasswordAuditServiceDelegate?


    init(hibpService: HIBPService, entries: [Entry]) {
        self.hibpService = hibpService
        self.entries = entries
    }


    func performAudit(completionHandler: @escaping (PasswordAuditResult) -> Void) {
        Diag.info("Starting password audit")
        guard ManagedAppConfig.shared.isPasswordAuditAllowed else {
            Diag.error("Forbidden by organization's policy, cancelling")
            completionHandler(.failure(.canceled))
            return
        }
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied, cancelling")
            completionHandler(.failure(.canceled))
            return
        }

        let progress = ProgressEx()
        progress.localizedDescription = LString.statusAuditingPasswords

        let reportProgress = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                progress.completedUnitCount += 1
                self?.delegate?.progressDidUpdate(progress: progress)
            }
        }

        entries.removeAll(where: {
            $0.isDeleted || ($0 as? Entry2)?.qualityCheck == false
        })

        guard !entries.isEmpty else {
            Diag.debug("Database has no entries, aborting")
            completionHandler(.success([]))
            return
        }

        if progress.isCancelled {
            Diag.debug("Cancelled by user while computing hashes")
            completionHandler(.failure(.canceled))
            return
        }

        let hashesDictionary = getHashDictionary(entries: entries)

        if progress.isCancelled {
            Diag.debug("Cancelled by user while trimming hashes")
            completionHandler(.failure(.canceled))
            return
        }

        let uniquePrefixes = Set(hashesDictionary.keys.map {
            $0.prefix(HIBPService.Constants.hashPrefixLength)
        })
        progress.totalUnitCount = Int64(uniquePrefixes.count)

        var results: [PasswordAudit] = []
        let group = DispatchGroup()
        for hashPrefix in uniquePrefixes {
            group.enter()
            hibpService.passwordRange(hashPrefix: String(hashPrefix)) { result in
                if progress.isCancelled {
                    group.leave()
                    DispatchQueue.main.async {
                        completionHandler(.failure(.canceled))
                    }
                    return
                }

                reportProgress()

                switch result {
                case let .success(data):
                    results.append(contentsOf: data.compactMap { item -> PasswordAudit? in
                        guard let record = hashesDictionary[item.hash] else {
                            return nil
                        }
                        return .init(entry: record, count: item.count)
                    })
                case let .failure(error):
                    DispatchQueue.main.async {
                        completionHandler(.failure(.requestError(error)))
                    }
                    progress.cancel()
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !progress.isCancelled else {
                Diag.debug("Password audit canceled by user")
                completionHandler(.failure(.canceled))
                return
            }

            Diag.debug("Password audit complete")
            completionHandler(.success(results.sorted(by: { $0.count > $1.count })))
        }
    }


    private func getHashDictionary(entries: [Entry]) -> [String: Entry] {
        var result = [String: Entry]()
        entries.forEach { entry in
            guard let data = entry.resolvedPassword.data(using: .utf8) else {
                return
            }
            let hash = Insecure.SHA1.hash(data: data)
            let hexHash = hash.compactMap { String(format: "%02x", $0) }.joined().uppercased()
            result[hexHash] = entry
        }
        return result
    }
}
