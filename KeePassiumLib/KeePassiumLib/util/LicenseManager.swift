//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public final class LicenseManager {
    public static let shared = LicenseManager()
    private static let provisionalLicenseCutoffDate = Date(iso8601string: "2024-02-29T23:59:59Z")!

    private enum LicenseKeyFormat {
        case version1 
        case provisional
        case unknown
    }

    private var cachedLicenseStatus: Bool?
    public func hasActiveBusinessLicense() -> Bool {
        if let cachedLicenseStatus {
            return cachedLicenseStatus
        }

        let licenseStatus = isLicensedForBusiness()
        cachedLicenseStatus = licenseStatus
        return licenseStatus
    }

    internal func checkBusinessLicense() {
        cachedLicenseStatus = isLicensedForBusiness()
    }

    private func isLicensedForBusiness() -> Bool {
        guard let licenseKey = ManagedAppConfig.shared.license else {
            return false
        }

        let keyFormat = getLicenseKeyFormat(licenseKey)
        switch keyFormat {
        case .version1:
            do {
                return try isValidLicenseV1(licenseKey)
            } catch {
                return false
            }
        case .provisional:
            let formattedDate = Self.provisionalLicenseCutoffDate.formatted(date: .numeric, time: .omitted)
            if Date.now.distance(to: Self.provisionalLicenseCutoffDate) > 0 {
                Diag.info("Using provisional business license [validUntil: \(formattedDate)]")
                return true
            } else {
                Diag.info("Provisional business license has expired [validUntil: \(formattedDate)]")
                return false
            }
        case .unknown:
            Diag.error("Business license key is misformatted")
            return false
        }
    }

    private func getLicenseKeyFormat(_ licenseKey: String) -> LicenseKeyFormat {
        if let _ = getLicenseDataV1(from: licenseKey) {
            return .version1
        }
        if licenseKey.lowercased() == "provisional" {
            return .provisional
        }
        return .unknown
    }
}

extension LicenseManager {
    private static let proofListFileName = "v1-proofs.sha256"
    private enum LicenseV1 {
        static let keyLength = 32 
        static let proofSize = SHA256_SIZE
    }

    private func getLicenseDataV1(from licenseKey: String) -> ByteArray? {
        guard licenseKey.count == LicenseV1.keyLength,
              let licenseData = ByteArray(hexString: licenseKey)
        else {
            return nil
        }
        return licenseData
    }

    private func isValidLicenseV1(_ licenseKey: String) throws -> Bool {
        guard let licenseData = getLicenseDataV1(from: licenseKey) else {
            Diag.warning("Unexpected license key format")
            return false
        }
        let licenseKeyHash = licenseData.sha256

        let proofListURL = Bundle.framework.url(
            forResource: Self.proofListFileName,
            withExtension: "",
            subdirectory: "")
        guard let proofListURL,
              let proofList = try? ByteArray(contentsOf: proofListURL)
        else {
            Diag.error("License proof list is missing")
            return false
        }

        let inputStream = proofList.asInputStream()
        inputStream.open()
        defer {
            inputStream.close()
        }
        while inputStream.hasBytesAvailable {
            guard let aProof = inputStream.read(count: LicenseV1.proofSize) else {
                Diag.error("License hash list is corrupted")
                return false
            }
            if aProof == licenseKeyHash {
                Diag.debug("License key is valid [hashPrefix: \(licenseKeyHash.prefix(8).asHexString)]")
                return true
            }
        }
        Diag.error("License key invalid [hash: \(licenseKeyHash.asHexString)]")
        return false
    }
}
