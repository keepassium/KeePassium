//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum FileType {
    public static let attachmentUTIs = ["public.data", "public.content"]
    
    public static let databaseUTIs = [
        "public.data", "public.content", 
        "com.keepassium.kdb", "com.keepassium.kdbx",
        "com.jflan.MiniKeePass.kdb", "com.jflan.MiniKeePass.kdbx",
        "com.kptouch.kdb", "com.kptouch.kdbx",
        "com.markmcguill.strongbox.kdb",
        "com.markmcguill.strongbox.kdbx",
        "be.kyuran.kypass.kdb",
        "org.keepassxc"]
    
    public static let keyFileUTIs =
        ["com.keepassium.keyfile", "public.data", "public.content"]

    public enum DatabaseExtensions {
        public static let all = [kdb, kdbx]
        public static let kdb = "kdb"
        public static let kdbx = "kdbx"
    }

    
    
    case database
    case keyFile

    init(for url: URL) {
        if FileType.DatabaseExtensions.all.contains(url.pathExtension) {
            self = .database
        } else {
            self = .keyFile
        }
    }

    public static func isDatabaseFile(url: URL) -> Bool {
        return DatabaseExtensions.all.contains(url.pathExtension)
    }
}
