//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

class FileInfoReloader {
    
    private let refreshQueue = DispatchQueue(
        label: "com.keepassium.FileInfoReloader",
        qos: .background,
        attributes: .concurrent)
    
    public func reload(_ refs: [URLReference], completion: @escaping (() -> Void)) {
        for urlRef in refs {
            refreshQueue.async { [weak self] in
                self?.refreshFileAttributes(urlRef: urlRef)
            }
        }
        refreshQueue.asyncAfter(deadline: .now(), qos: .background, flags: .barrier) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    private func refreshFileAttributes(urlRef: URLReference)
    {
        guard let url = try? urlRef.resolve() else {
            urlRef.refreshInfo()
            return
        }
        
        let document = FileDocument(fileURL: url)
        document.open(
            successHandler: {
                urlRef.refreshInfo()
                document.close(completionHandler: nil)
            },
            errorHandler: { (error) in
                urlRef.refreshInfo()
            }
        )
    }
}
