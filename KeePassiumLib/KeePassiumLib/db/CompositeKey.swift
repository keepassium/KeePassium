//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class CompositeKey: Codable {
    public enum State: Int, Comparable, Codable {
        case empty               = 0 
        case rawComponents       = 1 
        case processedComponents = 2 
        case combinedComponents  = 3 
        case final = 4
        
        public static func < (lhs: CompositeKey.State, rhs: CompositeKey.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    static let empty = CompositeKey()

    internal private(set) var state: State
    
    internal private(set) var password: String = ""
    internal private(set) var keyFileRef: URLReference?
    public var challengeHandler: ChallengeHandler? 
    
    internal private(set) var passwordData: SecureByteArray?
    internal private(set) var keyFileData: ByteArray?
    
    internal private(set) var combinedStaticComponents: SecureByteArray?
    
    internal private(set) var finalKey: SecureByteArray?
    internal private(set) var cipherKey: SecureByteArray?
    
    
    init() {
        self.password = ""
        self.keyFileRef = nil
        self.challengeHandler = nil
        state = .empty
    }
    
    init(password: String, keyFileRef: URLReference?, challengeHandler: ChallengeHandler?) {
        self.password = password
        self.keyFileRef = keyFileRef
        self.challengeHandler = challengeHandler
        state = .rawComponents
    }
    
    init(
        passwordData: SecureByteArray,
        keyFileData: ByteArray,
        challengeHandler: ChallengeHandler?)
    {
        self.password = ""
        self.keyFileRef = nil
        self.passwordData = passwordData
        self.keyFileData = keyFileData
        self.challengeHandler = challengeHandler
        
        state = .processedComponents
    }
    
    init(staticComponents: SecureByteArray, challengeHandler: ChallengeHandler?) {
        self.password = ""
        self.keyFileRef = nil
        self.passwordData = nil
        self.keyFileData = nil
        self.combinedStaticComponents = staticComponents
        self.challengeHandler = challengeHandler
        state = .combinedComponents
    }
    
    deinit {
        erase()
    }
    
    func erase() {
        keyFileRef = nil
        challengeHandler = nil
        passwordData = nil
        keyFileData = nil
        combinedStaticComponents = nil
        
        state = .empty
    }

    
    private enum CodingKeys: String, CodingKey {
        case state
        case passwordData
        case keyFileData
        case combinedStaticComponents = "staticComponents"
        case cipherKey
        case finalKey
    }
    
    internal func serialize() -> SecureByteArray {
        let encoder = JSONEncoder()
        let encodedBytes = SecureByteArray(data: try! encoder.encode(self))
        return encodedBytes
    }
    
    internal static func deserialize(from bytes: SecureByteArray?) -> CompositeKey? {
        guard let data = bytes?.asData else { return nil }
        let decoder = JSONDecoder()
        let result = try? decoder.decode(CompositeKey.self, from: data)
        return result
    }
    
    
    public func clone() -> CompositeKey {
        let clone = CompositeKey(
            password: self.password,
            keyFileRef: self.keyFileRef,
            challengeHandler: self.challengeHandler)
        clone.passwordData = self.passwordData?.secureClone()
        clone.keyFileData = self.keyFileData?.clone()
        clone.combinedStaticComponents = self.combinedStaticComponents?.secureClone()
        clone.cipherKey = self.cipherKey?.secureClone()
        clone.finalKey = self.finalKey?.secureClone()
        clone.state = self.state
        return clone
    }
    
    func setProcessedComponents(passwordData: SecureByteArray, keyFileData: ByteArray) {
        assert(state == .rawComponents)
        self.passwordData = passwordData.secureClone()
        self.keyFileData = keyFileData.clone()
        state = .processedComponents
        
        self.password.erase()
        self.keyFileRef = nil
        self.cipherKey?.erase()
        self.cipherKey = nil
        self.finalKey?.erase()
        self.finalKey = nil
    }
    
    func setCombinedStaticComponents(_ staticComponents: SecureByteArray) {
        assert(state <= .combinedComponents)
        self.combinedStaticComponents = staticComponents.secureClone()
        state = .combinedComponents
        
        self.password.erase()
        self.keyFileRef = nil
        self.passwordData?.erase()
        self.passwordData = nil
        self.keyFileData?.erase()
        self.keyFileData = nil
        
        self.cipherKey?.erase()
        self.cipherKey = nil
        self.finalKey?.erase()
        self.finalKey = nil
    }
    
    func setFinalKeys(_ finalKey: SecureByteArray, _ cipherKey: SecureByteArray?) {
        assert(state >= .combinedComponents)
        self.cipherKey = cipherKey?.secureClone()
        self.finalKey = finalKey.secureClone()
        state = .final
    }
    
    func eraseFinalKeys() {
        guard state >= .final else { return }
        state = .combinedComponents
        cipherKey?.erase()
        cipherKey = nil
        finalKey?.erase()
        finalKey = nil
    }
    
    func getResponse(challenge: SecureByteArray) throws -> SecureByteArray  {
        guard let handler = self.challengeHandler else {
            return SecureByteArray()
        }
        
        
        var response: SecureByteArray?
        var challengeError: ChallengeResponseError?
        let responseReadySemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .default).async {
            handler(challenge) {
                (_response, _error) in
                if let _error = _error {
                    challengeError = _error
                    responseReadySemaphore.signal()
                    return
                }
                response = _response
                responseReadySemaphore.signal()
            }
        }
        responseReadySemaphore.wait()
        
        if let challengeError = challengeError {
            switch challengeError {
            case .cancelled:
                throw ProgressInterruption.cancelled(reason: ProgressEx.CancellationReason.userRequest)
            default:
                throw challengeError 
            }
        }
        if let response = response {
            return response.sha256
        }
        preconditionFailure("You should not be here")
    }
}
