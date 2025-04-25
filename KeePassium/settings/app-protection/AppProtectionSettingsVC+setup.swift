//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension AppProtectionSettingsVC {
    internal func _setupCollectionView() {
        var layoutConfig = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        layoutConfig.headerMode = .supplementary
        layoutConfig.footerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: layoutConfig)

        _collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        _collectionView.delegate = self
        view.addSubview(_collectionView)

        _collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            _collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            _collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            _collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        _collectionView.alwaysBounceVertical = false
        _collectionView.allowsFocus = true
        _collectionView.allowsSelection = false
    }

    internal func _setupDataSource() {
        let basicCellRegistration = BasicCell.makeRegistration()
        let toggleCellRegistration = ToggleCell.makeRegistration()
        let pickerCellRegistration = PickerCell.makeRegistration()

        _dataSource = UICollectionViewDiffableDataSource<Section, SettingsItem>(collectionView: _collectionView) {
            collectionView, indexPath, item in
            switch item {
            case .navigation:
                return collectionView
                    .dequeueConfiguredReusableCell(using: basicCellRegistration, for: indexPath, item: item)
            case .toggle:
                return collectionView
                    .dequeueConfiguredReusableCell(using: toggleCellRegistration, for: indexPath, item: item)
            case .picker:
                return collectionView
                    .dequeueConfiguredReusableCell(using: pickerCellRegistration, for: indexPath, item: item)
            }
        }

        let headerCellRegistration = makeHeaderCellRegistration()
        let footerCellRegistration = makeFooterCellRegistration()
        _dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView
                    .dequeueConfiguredReusableSupplementary(using: headerCellRegistration, for: indexPath)
            case UICollectionView.elementKindSectionFooter:
                return collectionView
                    .dequeueConfiguredReusableSupplementary(using: footerCellRegistration, for: indexPath)
            default:
                return nil
            }
        }
    }

    private func makeHeaderCellRegistration()
        -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) {
            supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            let section = Section.allCases[indexPath.section]
            content.text = section.header
            supplementaryView.contentConfiguration = content
        }
    }

    private func makeFooterCellRegistration()
        -> UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) {
            supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            let section = Section.allCases[indexPath.section]
            content.text = section.footer
            supplementaryView.contentConfiguration = content
        }
    }

}
