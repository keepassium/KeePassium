//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UniformTypeIdentifiers

public enum FileType {
    public static let attachmentUTIs: [UTType] = [.data, .content]
    
    public static let databaseUTIs: [UTType] = [
        .data, .content, 
        .item, 
        .init("com.keepassium.kdb")!, .init("com.keepassium.kdbx")!,
        .init("com.maxep.mikee.kdb")!, .init("com.maxep.mikee.kdbx")!,
        .init("com.jflan.MiniKeePass.kdb")!, .init("com.jflan.MiniKeePass.kdbx")!,
        .init("com.kptouch.kdb")!, .init("com.kptouch.kdbx")!,
        .init("com.markmcguill.strongbox.kdb")!,
        .init("com.markmcguill.strongbox.kdbx")!,
        .init("be.kyuran.kypass.kdb")!,
        .init("org.keepassxc")!]
    
    public static let keyFileUTIs: [UTType] =
        [.init("com.keepassium.keyfile")!, .data, .content, .item]

    public enum DatabaseExtensions {
        public static let all = [kdb, kdbx]
        public static let kdb = "kdb"
        public static let kdbx = "kdbx"
    }

    
    
    case database
    case keyFile

    init(for url: URL) {
        if FileType.DatabaseExtensions.all.contains(url.pathExtension.localizedLowercase) {
            self = .database
        } else {
            self = .keyFile
        }
    }

    public static func isDatabaseFile(url: URL) -> Bool {
        return DatabaseExtensions.all.contains(url.pathExtension.localizedLowercase)
    }
}
