//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class ProgressEx: Progress {
    public enum CancellationReason {
        case userRequest
        case lowMemoryWarning
        
        var localizedDescription: String {
            switch self {
            case .userRequest:
                return NSLocalizedString(
                    "[Progress/CancellationReason] Cancelled by user",
                    bundle: Bundle.framework,
                    value: "Cancelled by user",
                    comment: "Explanation/notification when a long-running operation was cancelled by user")
            case .lowMemoryWarning:
                return NSLocalizedString(
                    "[Progress/CancellationReason/lowMemory]",
                    bundle: Bundle.framework,
                    value: "Not enough memory to continue.\nThis can happen with larger databases or too ambitious database settings (Argon2 memory parameter).",
                    comment: "Error message when a long-running operation was cancelled due to the lack of free memory (RAM).")
            }
        }
    }
    
    public var status: String {
        get { return localizedDescription }
        set { localizedDescription = newValue }
    }
    
    public override var localizedDescription: String! {
        didSet {
            parent?.localizedDescription = localizedDescription
        }
    }
    
    public private(set) var cancellationReason: CancellationReason = .userRequest {
        didSet {
            children.forEach {
                $0.value?.cancellationReason = cancellationReason
            }
        }
    }
    
    private var children = [Weak<ProgressEx>]()
    
    private weak var parent: ProgressEx?
    
    override public init(
        parent parentProgressOrNil: Progress?,
        userInfo userInfoOrNil: [ProgressUserInfoKey : Any]? = nil)
    {
        super.init(parent: parentProgressOrNil, userInfo: userInfoOrNil)
    }
    
    public override func addChild(_ child: Progress, withPendingUnitCount inUnitCount: Int64) {
        if let child = child as? ProgressEx {
            child.parent = self
            children.append(Weak(child))
        } else {
            assertionFailure()
        }
        super.addChild(child, withPendingUnitCount: inUnitCount)
        if child.localizedDescription != nil {
            self.localizedDescription = child.localizedDescription
        }
    }
    
    public func cancel(reason: CancellationReason) {
        self.cancellationReason = reason
        super.cancel()
    }
}

