//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

class FileInfoReloader: Synchronizable {
    static let timeout = URLReference.defaultTimeout

    public var isRefreshing: Bool {
        return synchronized { [self] in
            self.refreshingRefsCount > 0
        }
    }

    private var refreshingRefsCount = 0
    
    typealias UpdateHandler = (_ ref: URLReference) -> ()
    
    
    public func getInfo(
        for refs: [URLReference],
        update updateHandler: @escaping UpdateHandler,
        completion: @escaping ()->())
    {
        guard refs.count > 0 else {
            completion()
            return
        }
        
        for ref in refs {
            guard !ref.isRefreshingInfo else {
                continue
            }
            synchronized { refreshingRefsCount += 1 }
            ref.refreshInfo { [weak self] result in
                guard let self = self else { return }
                self.synchronized {
                    self.refreshingRefsCount -= 1
                }
                switch result {
                case .success:
                    updateHandler(ref)
                case .failure(let error):
                    Diag.warning("Failed to get file info [reason: \(error.localizedDescription)]")
                    updateHandler(ref)
                }
                if !self.isRefreshing {
                    completion()
                }
            }
        }
    }
}
