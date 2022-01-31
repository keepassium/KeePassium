//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
    
    internal private(set) var passwordData: SecureBytes?
    internal private(set) var keyFileData: SecureBytes?
    
    internal private(set) var combinedStaticComponents: SecureBytes?
    
    internal private(set) var finalKey: SecureBytes?
    internal private(set) var cipherKey: SecureBytes?
    
    
    public init() {
        self.password = ""
        self.keyFileRef = nil
        self.challengeHandler = nil
        state = .empty
    }
    
    public init(password: String, keyFileRef: URLReference?, challengeHandler: ChallengeHandler?) {
        self.password = password
        self.keyFileRef = keyFileRef
        self.challengeHandler = challengeHandler
        state = .rawComponents
    }
    
    init(staticComponents: SecureBytes, challengeHandler: ChallengeHandler?) {
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
    
    
    public func clone() -> CompositeKey {
        let clone = CompositeKey(
            password: self.password,
            keyFileRef: self.keyFileRef,
            challengeHandler: self.challengeHandler)
        clone.passwordData = self.passwordData?.clone()
        clone.keyFileData = self.keyFileData?.clone()
        clone.combinedStaticComponents = self.combinedStaticComponents?.clone()
        clone.cipherKey = self.cipherKey?.clone()
        clone.finalKey = self.finalKey?.clone()
        clone.state = self.state
        return clone
    }
    
    func setProcessedComponents(passwordData: SecureBytes, keyFileData: SecureBytes) {
        assert(state == .rawComponents)
        self.passwordData = passwordData.clone()
        self.keyFileData = keyFileData.clone()
        state = .processedComponents
        
        self.password.erase()
        self.keyFileRef = nil
        self.cipherKey?.erase()
        self.cipherKey = nil
        self.finalKey?.erase()
        self.finalKey = nil
    }
    
    func setCombinedStaticComponents(_ staticComponents: SecureBytes) {
        assert(state <= .combinedComponents)
        self.combinedStaticComponents = staticComponents.clone()
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
    
    func setFinalKeys(_ finalKey: SecureBytes, _ cipherKey: SecureBytes?) {
        assert(state >= .combinedComponents)
        self.cipherKey = cipherKey?.clone()
        self.finalKey = finalKey.clone()
        state = .final
    }
    
    public func eraseFinalKeys() {
        guard state >= .final else { return }
        state = .combinedComponents
        cipherKey?.erase()
        cipherKey = nil
        finalKey?.erase()
        finalKey = nil
    }
    
    func getResponse(challenge: SecureBytes) throws -> SecureBytes  {
        guard let handler = self.challengeHandler else {
            return SecureBytes.empty()
        }
        
        
        var response: SecureBytes?
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
