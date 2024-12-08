//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

class AESKDF: KeyDerivationFunction {

    internal static let _uuid = UUID(uuid: (
        0xC9, 0xD9, 0xF3, 0x9A, 0x62, 0x8A, 0x44, 0x60,
        0xBF, 0x74, 0x0D, 0x08, 0xC1, 0x8A, 0x4F, 0xEA))
    public static let transformSeedParam = "S"
    public static let transformRoundsParam = "R"

    public static let memoryFootprint: Int = 32

    public var uuid: UUID { return AESKDF._uuid }
    public var name: String { return "AES KDF" }

    private let subkeySize = 16
    private var progress = ProgressEx()

    static let defaultIterations: UInt64 = 100_000

    public var defaultParams: KDFParams {
        let params = KDFParams()
        params.setValue(key: KDFParams.uuidParam, value: VarDict.TypedValue(value: uuid.data))

        let transformSeed = ByteArray(count: SHA256_SIZE) 
        params.setValue(
            key: AESKDF.transformSeedParam,
            value: VarDict.TypedValue(value: transformSeed))
        params.setValue(
            key: AESKDF.transformRoundsParam,
            value: VarDict.TypedValue(value: Self.defaultIterations))
        return params
    }

    required init() {
    }

    func parseParams(_ kdfParams: KDFParams, to settings: inout EncryptionSettings) {
        settings.iterations = kdfParams.getValue(key: AESKDF.transformRoundsParam)?.asUInt64()
        settings.memory = nil
        settings.parallelism = nil
    }

    func getPeakMemoryFootprint(_ kdfParams: KDFParams) -> Int {
        return Self.memoryFootprint
    }

    func apply(_ settings: EncryptionSettings, to kdfParams: inout KDFParams) {
        assert(settings.iterations != nil, "Iterations parameter must be defined")
        let iterations = settings.iterations ?? Self.defaultIterations
        kdfParams.setValue(
            key: AESKDF.transformRoundsParam,
            value: VarDict.TypedValue(value: iterations))
    }

    func initProgress() -> ProgressEx {
        progress = ProgressEx()
        progress.localizedDescription = NSLocalizedString(
            "[KDF/Progress] Processing the master key",
            bundle: Bundle.framework,
            value: "Processing the master key",
            comment: "Status message: processing of the master key is in progress")
        return progress
    }

    func getChallenge(_ params: KDFParams) throws -> ByteArray {
        guard let transformSeed = params.getValue(key: AESKDF.transformSeedParam)?.asByteArray() else {
            throw CryptoError.invalidKDFParam(kdfName: name, paramName: AESKDF.transformSeedParam)
        }
        return transformSeed
    }

    func randomize(params: inout KDFParams) throws {
        let transformSeed = try CryptoManager.getRandomBytes(count: SHA256_SIZE)
        params.setValue(
            key: AESKDF.transformSeedParam,
            value: VarDict.TypedValue(value: transformSeed))
    }

    func transform(key compositeKey: SecureBytes, params: KDFParams) throws -> SecureBytes {
        guard let transformSeed = params.getValue(key: AESKDF.transformSeedParam)?.asByteArray() else {
            throw CryptoError.invalidKDFParam(kdfName: name, paramName: AESKDF.transformSeedParam)
        }
        guard let transformRounds = params.getValue(key: AESKDF.transformRoundsParam)?.asUInt64() else {
            throw CryptoError.invalidKDFParam(kdfName: name, paramName: AESKDF.transformRoundsParam)
        }
        assert(transformSeed.count == Int(kCCKeySizeAES256))
        assert(compositeKey.count == SHA256_SIZE)

        progress.totalUnitCount = Int64(transformRounds)

        var transformedKey = SecureBytes.empty()
        let status = transformSeed.withBytes { trSeedBytes  in
            return compositeKey.withDecryptedMutableBytes { (trKeyBytes: inout [UInt8]) -> Int32 in


                let progressPtr = UnsafeRawPointer(Unmanaged.passUnretained(progress).toOpaque())
                // swiftlint:disable opening_brace closure_parameter_position
                let status = aeskdf_rounds(
                    trSeedBytes,
                    &trKeyBytes,
                    transformRounds,
                    {
                        (round: UInt64, progressPtr: Optional<UnsafeRawPointer>) -> Int32 in
                        guard let progressPtr = progressPtr else {
                            return 0 /* continue transformations */
                        }
                        let progress = Unmanaged<ProgressEx>
                            .fromOpaque(progressPtr)
                            .takeUnretainedValue()
                        progress.completedUnitCount = Int64(round)
                        let isShouldStop: Int32 = progress.isCancelled ? 1 : 0
                        return isShouldStop
                    },
                    progressPtr)
                // swiftlint:enable opening_brace closure_parameter_position
                let transformedKeyBytes = CryptoManager.sha256(of: trKeyBytes)
                transformedKey = SecureBytes.from(transformedKeyBytes)
                return status
            }
        }
        progress.completedUnitCount = progress.totalUnitCount
        if progress.isCancelled {
            throw ProgressInterruption.cancelled(reason: progress.cancellationReason)
        }

        guard status == kCCSuccess else {
            Diag.error("doRounds() crypto error [code: \(status)]")
            throw CryptoError.aesEncryptError(code: Int(status))
        }
        return transformedKey
    }
}
