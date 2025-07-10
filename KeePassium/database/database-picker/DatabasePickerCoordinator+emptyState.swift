//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    enum EmptyListConfigurator {
        static func makeConfiguration(
            for coordinator: DatabasePickerCoordinator
        ) -> UIContentUnavailableConfiguration {
            var config = UIContentUnavailableConfiguration.empty()
            config.text = LString.titleNoDatabaseFiles
            config.textProperties.color = .placeholderText
            config.image = UIImage(asset: .noDatabases)
            config.imageProperties.maximumSize = CGSize(width: 64, height: 64)
            config.imageProperties.tintColor = .placeholderText

            let appConfig = ManagedAppConfig.shared
            if appConfig.areSystemFileProvidersAllowed {
                var buttonConfig = UIButton.Configuration.plain()
                buttonConfig.title = LString.actionOpenDatabase
                config.button = buttonConfig
                config.buttonProperties.primaryAction = UIAction {
                    [weak coordinator] action in
                    guard let coordinator else { return }
                    coordinator.startExternalDatabasePicker(presenter: coordinator._filePickerVC)
                }
            }
            if appConfig.areInAppFileProvidersAllowed {
                var secondButtonConfig = UIButton.Configuration.plain()
                secondButtonConfig.title = LString.actionConnectToServer
                config.secondaryButton = secondButtonConfig
                config.secondaryButtonProperties.primaryAction = UIAction {
                    [weak coordinator] action in
                    guard let coordinator else { return }
                    coordinator.startRemoteDatabasePicker(presenter: coordinator._filePickerVC)
                }
            }
            if appConfig.areSystemFileProvidersAllowed && appConfig.areInAppFileProvidersAllowed {
                config.buttonProperties.role = .primary
            }
            return config
        }
    }
}
