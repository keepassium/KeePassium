//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class FileDocument: UIDocument {
    public enum InternalError: LocalizedError {
        case generic
        public var errorDescription: String? {
            return NSLocalizedString(
                "[FileDocument] Unexpected file error, please contact us.",
                bundle: Bundle.framework,
                value: "Unexpected file error, please contact us.",
                comment: "A very generic error message")
        }
    }
    
    public var data = ByteArray()
    public private(set) var error: Error?
    public var hasError: Bool { return error != nil }
    
    public func open(successHandler: @escaping(() -> Void), errorHandler: @escaping((Error)->Void)) {
        super.open(completionHandler: { success in
            if success {
                self.error = nil
                successHandler()
            } else {
                guard let error = self.error else {
                    assertionFailure()
                    errorHandler(FileDocument.InternalError.generic)
                    return
                }
                errorHandler(error)
            }
        })
    }
    
    override public func contents(forType typeName: String) throws -> Any {
        error = nil
        return data.asData
    }
    
    override public func load(fromContents contents: Any, ofType typeName: String?) throws {
        assert(contents is Data)
        error = nil
        if let contents = contents as? Data {
            data = ByteArray(data: contents)
        } else {
            data = ByteArray()
        }
    }
    
    override public func handleError(_ error: Error, userInteractionPermitted: Bool) {
        self.error = error
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
    }
}
