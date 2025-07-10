//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

protocol SettingsSection: Hashable {
    var header: String? { get }
    var footer: String? { get }
}

class BaseSettingsViewController<Section: SettingsSection>:
    UIViewController,
    UICollectionViewDelegate,
    Refreshable
{
    typealias DataSource = UICollectionViewDiffableDataSource<Section, SettingsItem>

    internal var _collectionView: UICollectionView!
    internal var _dataSource: DataSource!

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemBackground
        _setupCollectionView()
        _setupDataSource()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func refresh() {
        fatalError("Pure abstract method, populate dataSource here")
    }

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
        let textScaleCellRegistration = TextScaleCell.makeRegistration()

        let dataSource = UICollectionViewDiffableDataSource<Section, SettingsItem>(collectionView: _collectionView) {
            collectionView, indexPath, item in
            switch item {
            case .basic:
                return collectionView.dequeueConfiguredReusableCell(
                    using: basicCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .toggle:
                return collectionView.dequeueConfiguredReusableCell(
                    using: toggleCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .picker:
                return collectionView.dequeueConfiguredReusableCell(
                    using: pickerCellRegistration,
                    for: indexPath,
                    item: item
                )
            case .textScale:
                return collectionView.dequeueConfiguredReusableCell(
                    using: textScaleCellRegistration,
                    for: indexPath,
                    item: item
                )
            }
        }

        let headerCellRegistration = makeHeaderCellRegistration()
        let footerCellRegistration = makeFooterCellRegistration()
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerCellRegistration,
                    for: indexPath
                )
            case UICollectionView.elementKindSectionFooter:
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: footerCellRegistration,
                    for: indexPath
                )
            default:
                return nil
            }
        }
        self._dataSource = dataSource
    }

    private func makeHeaderCellRegistration() ->
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) {
            [weak self] supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            guard let section = self?._dataSource.sectionIdentifier(for: indexPath.section) else {
                assertionFailure()
                return
            }
            content.text = section.header
            supplementaryView.contentConfiguration = content
        }
    }

    private func makeFooterCellRegistration() ->
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) {
            [weak self] supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            guard let section = self?._dataSource.sectionIdentifier(for: indexPath.section) else {
                assertionFailure()
                return
            }
            content.text = section.footer
            supplementaryView.contentConfiguration = content
        }
    }

    @objc func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    @objc func collectionView(
        _ collectionView: UICollectionView,
        shouldHighlightItemAt indexPath: IndexPath
    ) -> Bool {
        guard let item = _dataSource.itemIdentifier(for: indexPath) else {
            return false
        }
        return item.canBeHighlighted
    }

    @objc func collectionView(
        _ collectionView: UICollectionView,
        performPrimaryActionForItemAt indexPath: IndexPath
    ) {
        let targetItem = _dataSource.itemIdentifier(for: indexPath)
        switch targetItem {
        case .basic(let itemConfig):
            itemConfig.handler?()
        case .toggle, .picker, .textScale, .none:
            return
        }
    }
}
