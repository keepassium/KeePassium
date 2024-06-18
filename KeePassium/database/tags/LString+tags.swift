//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension LString {
    static let allTags = NSLocalizedString(
        "[Tags/Section/All]",
        value: "All Tags",
        comment: "Title of a list with all the tags existing in the database.")
    static let inheritedTags = NSLocalizedString(
        "[Tags/Section/Inherited]",
        value: "Inherited Tags",
        comment: "Title of a list with tags used by parent groups.")
    static let selectedTags = NSLocalizedString(
        "[Tags/Section/Selected]",
        value: "Selected Tags",
        comment: "Title of a list with tags chosen by the user for a specific entry or group.")

    static let titleNewTag = NSLocalizedString(
        "[Tags/Create/title]",
        value: "New Tag",
        comment: "Title of the tag creation dialog")
    static let actionCreateTag = NSLocalizedString(
        "[Tags/Create/action]",
        value: "Create Tag",
        comment: "Action/button to create a new item tag")
    static let sampleTagsPlaceholder = NSLocalizedString(
        "[Tags/Create/placeholder]",
        value: "Enter tag name",
        comment: "Call to action/hint inside a text input")

    static let titleEditTag = NSLocalizedString(
        "[Tags/Edit/title]",
        value: "Edit Tag",
        comment: "Title of a dialog for editing a tag")
    static let confirmDeleteTag = NSLocalizedString(
        "[Tags/Delete/Confirm/message]",
        value: "Delete this tag from all groups and entries?",
        comment: "Question to confirm global deletion")

    static let statusNoTagsFound = NSLocalizedString(
        "[Tags/Search/emptyResult]",
        value: "No suitable tags found.",
        comment: "Status message: tag search result is empty")
    static let statusNoTagsInDatabase = NSLocalizedString(
        "[Tags/None/placeholder]",
        value: "There are no tags in the database, add some.",
        comment: "Status message with a call to action")
    static let tagUsageCount = NSLocalizedString(
        "[Tags/UsageCount/title]",
        value: "Usage count",
        comment: "Title: the number of times a tag is encountered in the database.")

}
