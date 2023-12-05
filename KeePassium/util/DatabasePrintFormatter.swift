//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class DatabasePrintFormatter {
    typealias Level = Int

    private enum Predefined {
        static let itemIconSide = CGFloat(12.0)
        static let fieldIconSide = CGFloat(10.0)
        static let indentStep = CGFloat(20.0)

        static let documentTitleFont = UIFont.boldSystemFont(ofSize: 16.0)
        static let groupTitleFont = UIFont.boldSystemFont(ofSize: 12.0)
        static let entryTitleFont = UIFont.systemFont(ofSize: 12.0)
        static let fieldNameFont = UIFont.boldSystemFont(ofSize: 10.0).addingTraits(.traitItalic)
        static let fieldValueFont = UIFont.monospacedSystemFont(ofSize: 10.0, weight: .regular)

        static let documentHeaderParagraphStyle: NSParagraphStyle = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineHeightMultiple = 1.2
            paragraphStyle.paragraphSpacing = 6.0
            paragraphStyle.paragraphSpacingBefore = 6.0
            return paragraphStyle
        }()
    }


    private var groupParagraphStyles = [Level: NSParagraphStyle]()
    private var entryParagraphStyles = [Level: NSParagraphStyle]()
    private var fieldParagraphStyles = [Level: NSParagraphStyle]()

    private let iconSymbolForField: [String: SymbolName] = [
        EntryField.userName: .person,
        EntryField.password: .asterisk,
        EntryField.url: .globe,
        EntryField.notes: .noteText,
    ]
}

extension DatabasePrintFormatter {

    public func toAttributedString(database: Database, title: String) -> NSAttributedString? {
        let documentContent = NSMutableAttributedString()
        documentContent.append(NSAttributedString(
            string: title + "\n",
            attributes: [
                NSAttributedString.Key.font: Predefined.documentTitleFont,
                NSAttributedString.Key.paragraphStyle: Predefined.documentHeaderParagraphStyle,
                NSAttributedString.Key.foregroundColor: UIColor.darkText,
            ]
        ))
        guard let root = database.root else {
            Diag.info("Database is empty")
            return documentContent
        }
        sortAndFormat(group: root, level: 0, to: documentContent)
        return documentContent
    }

    private func sortAndFormat(
        group: Group,
        level: Level,
        to documentContent: NSMutableAttributedString
    ) {
        if level > 0 {
            documentContent.append(format(group: group, level: level))
        }

        let sortOrder = Settings.current.groupSortOrder
        let sortedGroups = group.groups.sorted { sortOrder.compare($0, $1) }
        sortedGroups
            .filter { !$0.isDeleted }
            .forEach {
                sortAndFormat(group: $0, level: level + 1, to: documentContent)
            }
        let sortedEntries = group.entries.sorted { sortOrder.compare($0, $1) }
        sortedEntries
            .filter { !$0.isDeleted }
            .forEach {
                documentContent.append(format(entry: $0, level: level + 1))
            }
    }
}

extension DatabasePrintFormatter {
    private func getGroupParagraphStyle(level: Level) -> NSParagraphStyle {
        if let style = groupParagraphStyles[level] {
            return style
        }
        let indent = Predefined.indentStep * CGFloat(level - 1)
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        style.lineHeightMultiple = 1.0
        style.paragraphSpacing = 6.0
        style.paragraphSpacingBefore = 6.0
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        groupParagraphStyles[level] = style
        return style
    }

    private func getEntryParagraphStyle(level: Level) -> NSParagraphStyle {
        if let style = entryParagraphStyles[level] {
            return style
        }
        let indent = Predefined.indentStep * CGFloat(level - 1)
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        style.lineHeightMultiple = 1.2
        style.paragraphSpacing = 6.0
        style.paragraphSpacingBefore = 6.0
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        entryParagraphStyles[level] = style
        return style
    }

    private func getFieldParagraphStyle(level: Level) -> NSParagraphStyle {
        if let style = fieldParagraphStyles[level] {
            return style
        }
        let entryIndent = Predefined.indentStep * CGFloat(level - 1)
        let indent = entryIndent + Predefined.itemIconSide + Predefined.indentStep

        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        style.lineHeightMultiple = 1.0
        style.paragraphSpacing = 0.0
        style.paragraphSpacingBefore = 0.0
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        fieldParagraphStyles[level] = style
        return style
    }

    private func renderIcon(
        _ icon: UIImage?,
        size: CGFloat = Predefined.itemIconSide,
        forFont font: UIFont
    ) -> NSAttributedString? {
        guard let icon else { return nil }
        var image: UIImage?
        if icon.isSymbolImage {
            image = icon
                .withRenderingMode(.alwaysOriginal) 
                .applyingSymbolConfiguration( 
                    .init(pointSize: font.pointSize * 5, weight: .semibold))?
                .stretchableImage(withLeftCapWidth: 0, topCapHeight: 0) 
        }
        guard image != nil else {
            return nil
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        let iconSize = CGSize(width: size, height: size)
        attachment.bounds = CGRect(
            x: CGFloat(0),
            y: (font.capHeight - iconSize.height) / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        return NSAttributedString(attachment: attachment)
    }

    private func format(group: Group, level: Level) -> NSAttributedString {
        let titleFont = Predefined.groupTitleFont
        let attributes = [
            NSAttributedString.Key.font: titleFont,
            NSAttributedString.Key.paragraphStyle: getGroupParagraphStyle(level: level),
            NSAttributedString.Key.foregroundColor: UIColor.darkText
        ]
        let result = NSMutableAttributedString(
            string: "\u{200B}\u{2002}", 
            attributes: attributes
        )
        if let icon = renderIcon(.kpIcon(forGroup: group), forFont: titleFont) {
            result.insert(icon, at: 1)
        }
        result.append(NSAttributedString(string: "\(group.name)\n", attributes: attributes))

        return result
    }

    private func format(entry: Entry, level: Level) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleFont = Predefined.entryTitleFont
        var attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .paragraphStyle: getEntryParagraphStyle(level: level),
            .foregroundColor: UIColor.darkText
        ]
        result.append(NSAttributedString(
            string: "\u{200B}\u{2002}", 
            attributes: attributes
        ))
        if let icon = renderIcon(.kpIcon(forEntry: entry), forFont: titleFont) {
            result.insert(icon, at: 1)
        }

        if entry.isExpired {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = UIColor.darkText.withAlphaComponent(0.7)
        }
        result.append(NSAttributedString(
            string: "\(entry.resolvedTitle)\n",
            attributes: attributes
        ))

        entry.fields.forEach { field in
            if field.value.isNotEmpty,
               field.name != EntryField.title 
            {
                result.append(format(field: field, level: level))
            }
        }
        return result
    }

    private func formatFieldName(_ field: EntryField, level: Level) -> NSMutableAttributedString {
        let nameAttributes = [
            NSAttributedString.Key.font: Predefined.fieldNameFont,
            NSAttributedString.Key.paragraphStyle: getFieldParagraphStyle(level: level),
            NSAttributedString.Key.foregroundColor: UIColor.darkText
        ]

        if let iconSymbol = iconSymbolForField[field.name],
           let icon = renderIcon(
                .symbol(iconSymbol),
                size: Predefined.fieldIconSide,
                forFont: Predefined.fieldNameFont)
        {
            let result = NSMutableAttributedString(string: "\u{200B}", attributes: nameAttributes)
            result.append(icon)
            return result
        }
        return NSMutableAttributedString(string: field.name, attributes: nameAttributes)
    }

    private func format(field: EntryField, level: Level) -> NSAttributedString {
        let result = formatFieldName(field, level: level)
        result.append(NSAttributedString(
            string: "\u{00a0}\u{00a0}\(field.resolvedValue)\n", 
            attributes: [
                NSAttributedString.Key.font: Predefined.fieldValueFont,
                NSAttributedString.Key.paragraphStyle: getFieldParagraphStyle(level: level),
                NSAttributedString.Key.foregroundColor: UIColor.darkText
            ]
        ))
        return result
    }
}

fileprivate extension Group {
    func getLevel() -> DatabasePrintFormatter.Level {
        var result = 0
        var p = self.parent
        while p != nil {
            p = p?.parent
            result += 1
        }
        return result
    }
}
