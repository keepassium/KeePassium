//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

final class HIBPService {
    enum Constants {
        static let connectionTimeout: TimeInterval = 5
        static let hashPrefixLength = 5
        static let hibpRangeURL = URL(string: "https://api.pwnedpasswords.com/range/")!
    }


    typealias PasswordRangeResult = Result<[PasswordRange], PasswordRangeError>


    enum PasswordRangeError: LocalizedError {
        case invalidHash
        case invalidResponse
        case requestError(Error)
        var errorDescription: String? {
            switch self {
            case .invalidHash:
                return "Invalid hash"
            case .invalidResponse:
                return "Invalid response"
            case .requestError(let underlyingError):
                return underlyingError.localizedDescription
            }
        }
    }


    struct PasswordRange {
        let hash: String
        let count: Int
    }


    private lazy var urlSession: URLSession = {
        var config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = Constants.connectionTimeout
        config.timeoutIntervalForResource = Constants.connectionTimeout
        return URLSession(
            configuration: config
        )
    }()


    func passwordRange(hashPrefix: String, completionHandler: @escaping (PasswordRangeResult) -> Void) {
        guard hashPrefix.count == Constants.hashPrefixLength else {
            Diag.error("Invalid hash prefix")
            completionHandler(.failure(.invalidHash))
            return
        }

        let url = Constants.hibpRangeURL.appendingPathComponent(hashPrefix)

        let task = urlSession.dataTask(with: .init(url: url)) { data, _, error in
            if let error = error {
                Diag.error("HIBP request failed [hasPrefix: \(hashPrefix), error: \(error)]")
                completionHandler(.failure(.requestError(error)))
                return
            }

            guard let data = data,
                  let string = String(data: data, encoding: .utf8)
            else {
                Diag.error("HIBP request failed because of empty response [hashPrefix: \(hashPrefix)]")
                completionHandler(.failure(.invalidResponse))
                return
            }

            let results = string
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> PasswordRange? in
                    let parts = line.split(separator: ":")
                    guard parts.count == 2,
                          let count = Int(parts[1])
                    else {
                        return nil
                    }
                    return .init(hash: hashPrefix.uppercased() + String(parts[0]), count: count)
                }
            completionHandler(.success(results))
        }

        task.resume()
    }
}
