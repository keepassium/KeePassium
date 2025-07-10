//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension KeyFilePickerCoordinator {
    enum EmptyListConfigurator {
        static func makeConfiguration(
            for coordinator: KeyFilePickerCoordinator
        ) -> UIContentUnavailableConfiguration {
            var config = UIContentUnavailableConfiguration.empty()
            config.text = LString.titleNoKeyFiles
            config.textProperties.color = .placeholderText
            config.image = .symbol(.keyFile)
            config.imageProperties.preferredSymbolConfiguration = .init(pointSize: 64, weight: .light)
            config.imageProperties.tintColor = .placeholderText

            let appConfig = ManagedAppConfig.shared
            if appConfig.areSystemFileProvidersAllowed {
                var buttonConfig = UIButton.Configuration.plain()
                buttonConfig.title = LString.actionAddKeyFile
                config.button = buttonConfig
                config.buttonProperties.menu = coordinator._makeAddKeyFileMenu()
            }
            return config
        }
    }
}
