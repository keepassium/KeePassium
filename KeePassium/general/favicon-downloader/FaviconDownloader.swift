//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import RegexBuilder
import UIKit

final class FaviconDownloader {
    static let connectionTimeout: TimeInterval = 3


    struct DownloadedFavicon {
        let entry: Entry
        let image: UIImage
    }


    typealias DownloadFaviconResult = Result<UIImage?, DownloadFaviconError>
    typealias DownloadFaviconsResult = Result<[DownloadedFavicon], DownloadFaviconError>


    enum DownloadFaviconError: LocalizedError {
        case invalidURL
        case invalidData
        case canceled
        case requestError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidData:
                return "Invalid data"
            case .canceled:
                return "Canceled"
            case .requestError(let underlyingError):
                return underlyingError.localizedDescription
            }
        }
    }


    private static let linkRegexp = try! NSRegularExpression(pattern: "<link.*?>")

    private lazy var urlSession: URLSession = {
        var config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = Self.connectionTimeout
        config.timeoutIntervalForResource = Self.connectionTimeout
        return URLSession(configuration: config)
    }()


    func downloadFavicon(
        for url: URL,
        progressHandler: ((ProgressEx) -> Void)? = nil,
        completionHandler: @escaping (DownloadFaviconResult) -> Void
    ) {
        guard ManagedAppConfig.shared.isFaviconDownloadAllowed else {
            Diag.error("Forbidden by organization's policy, cancelling")
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied, cancelling")
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }

        let progress = ProgressEx()
        progress.localizedDescription = LString.statusDownloadingOneFavicon
        progress.totalUnitCount = 2
        progressHandler?(progress)

        Diag.debug("Favicon requested for \(url.absoluteString)")

        checkForLinkFavicon(url: url, progress: progress) { [weak self] result in
            if progress.isCancelled {
                completionHandler(.failure(.canceled))
                return
            }

            if case let .success(image) = result, let image {
                completionHandler(.success(image))
                return
            }

            progress.completedUnitCount = 1
            progressHandler?(progress)
            self?.checkForStandardFavicon(
                url: url,
                progress: progress,
                completionHandler: completionHandler)
        }
    }

    func downloadFavicons(
        for entries: [Entry],
        progressHandler: @escaping ((ProgressEx) -> Void),
        completionHandler: @escaping (DownloadFaviconsResult) -> Void
    ) {
        Diag.info("Starting favicons download")
        guard ManagedAppConfig.shared.isFaviconDownloadAllowed else {
            Diag.error("Forbidden by organization's policy, cancelling")
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied, cancelling")
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }

        let progress = ProgressEx()
        progress.localizedDescription = LString.statusDownloadingFavicons

        let entriesWithUrls = entries.compactMap { entry -> (Entry, URL)? in
            guard let url = URL.from(malformedString: entry.resolvedURL) else {
                return nil
            }
            return (entry, url)
        }

        progress.totalUnitCount = Int64(entriesWithUrls.count)
        progressHandler(progress)

        var results: [DownloadedFavicon] = []
        let dispatchGroup = DispatchGroup()

        for (entry, url) in entriesWithUrls {
            dispatchGroup.enter()

            downloadFavicon(for: url) { result in
                if progress.isCancelled {
                    dispatchGroup.leave()
                    DispatchQueue.main.async {
                        completionHandler(.failure(.canceled))
                    }
                    return
                }

                DispatchQueue.main.async {
                    progress.completedUnitCount += 1
                    progressHandler(progress)
                }

                switch result {
                case let .success(image):
                    if let image {
                        results.append(DownloadedFavicon(entry: entry, image: image))
                    }
                case .failure:
                    break
                }

                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            guard !progress.isCancelled else {
                Diag.debug("Favicons download canceled by user")
                completionHandler(.failure(.canceled))
                return
            }

            Diag.debug("Favicons download complete")
            completionHandler(.success(results))
        }
    }


    private func checkForStandardFavicon(
        url: URL,
        progress: ProgressEx,
        completionHandler: @escaping (DownloadFaviconResult) -> Void
    ) {
        let baseURL = URL(string: "/", relativeTo: url)
        guard let faviconURL = URL(string: Favicon.defaultFilename, relativeTo: baseURL) else {
            Diag.error("Failed to create favicon URL for \(url.absoluteString)")
            completionHandler(.failure(.invalidURL))
            return
        }

        Diag.debug("Checking for favicon at \(faviconURL)")
        downloadIcon(at: faviconURL, progress: progress, completionHandler: completionHandler)
    }

    private func checkForLinkFavicon(
        url: URL,
        progress: ProgressEx,
        completionHandler: @escaping (DownloadFaviconResult) -> Void
    ) {
        if progress.isCancelled {
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }

        Diag.debug("Checking HTML for favicon links")
        let task = urlSession.dataTask(with: URLRequest(url: url)) { [weak self] probablyHtmlData, _, error in
            if let error = error {
                Diag.error("Favicon request failed [error: \(error)]")
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    if nsError.code == NSURLErrorCancelled {
                        completionHandler(.failure(.canceled))
                    } else {
                        completionHandler(.failure(.requestError(error)))
                    }
                }
                return
            }

            let encoding = { (data: Data) -> String.Encoding in
                let detectedEncoding = NSString.stringEncoding(
                    for: data,
                    encodingOptions: nil,
                    convertedString: nil,
                    usedLossyConversion: nil)
                guard detectedEncoding != 0 else {
                    Diag.debug("Could not detect HTML encoding, falling back to ASCII")
                    return .ascii
                }
                return String.Encoding(rawValue: detectedEncoding)
            }

            guard let probablyHtmlData,
                  let html = String(data: probablyHtmlData, encoding: encoding(probablyHtmlData))
            else {
                Diag.debug("Received data is broken or not HTML")
                DispatchQueue.main.async {
                    completionHandler(.failure(.invalidData))
                }
                return
            }

            let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
            let linkTagMatches = Self.linkRegexp.matches(in: html, options: [], range: fullRange)
            guard !linkTagMatches.isEmpty else {
                Diag.debug("No icon links found in HTML")
                DispatchQueue.main.async {
                    completionHandler(.success(nil))
                }
                return
            }

            let icons = linkTagMatches.compactMap {
                let matchRange = Range($0.range(at: 0), in: html)!
                let linkTagString = String(html[matchRange])
                return Favicon(html: linkTagString, baseURL: url)
            }
            Diag.debug("Found \(icons.count) icon links in HTML")

            let appleTouchIcon = icons.first(where: { $0.type == .appleTouchIcon })
            let iconsBySize = icons.sorted(by: { $0.size.width > $1.size.width })

            guard let bestIcon = appleTouchIcon ?? iconsBySize.first else {
                DispatchQueue.main.async {
                    completionHandler(.failure(.invalidURL))
                }
                return
            }

            Diag.debug("Choosing \(bestIcon.type) of size \(bestIcon.size) as prefered favicon")
            self?.downloadIcon(
                at: bestIcon.url,
                progress: progress,
                completionHandler: completionHandler)
        }

        progress.onCancel = {
            task.cancel()
        }

        task.resume()
    }

    private func downloadIcon(
        at url: URL,
        progress: ProgressEx,
        completionHandler: @escaping (DownloadFaviconResult) -> Void
    ) {
        if progress.isCancelled {
            DispatchQueue.main.async {
                completionHandler(.failure(.canceled))
            }
            return
        }

        Diag.debug("Downloading favicon at \(url.absoluteString)")
        let task = urlSession.dataTask(with: URLRequest(url: url)) { probablyImageData, response, error in
            if let error {
                Diag.error("Favicon request failed [message: \(error.localizedDescription)]")
                DispatchQueue.main.async {
                    if (error as NSError).code == NSURLErrorCancelled {
                        completionHandler(.failure(.canceled))
                    } else {
                        completionHandler(.failure(.requestError(error)))
                    }
                }
                return
            }

            let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(httpStatusCode) else {
                Diag.debug("No valid favicon found [status: \(httpStatusCode), url: \(url.absoluteString)]")
                DispatchQueue.main.async {
                    completionHandler(.success(nil))
                }
                return
            }

            guard let probablyImageData,
                  let image = UIImage(data: probablyImageData)
            else {
                Diag.debug("No valid favicon found [url: \(url.absoluteString)]")
                DispatchQueue.main.async {
                    completionHandler(.failure(.invalidData))
                }
                return
            }

            Diag.debug("Favicon downloaded")
            DispatchQueue.main.async {
                completionHandler(.success(image))
            }
        }

        progress.onCancel = {
            task.cancel()
        }

        task.resume()
    }
}
