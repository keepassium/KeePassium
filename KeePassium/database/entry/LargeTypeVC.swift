//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import UIKit

final class LargeTypeVC: UICollectionViewController {
    private enum CellID {
        static let letterCell = "LetterCell"
    }
    private let primaryFontSize: CGFloat = 44
    private let verticalSpacing: CGFloat = 4.0
    private let horizontalSpacing: CGFloat = 8.0

    private var cellHeight: CGFloat {
        return itemCellConfiguration.textProperties.font.lineHeight
            + 3 * verticalSpacing
            + itemCellConfiguration.secondaryTextProperties.font.lineHeight
    }
    private var minimumCellWidth: Int {
        return Int(cellHeight * 0.8)
    }

    private lazy var itemCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.textProperties.color = .primaryText
        configuration.textProperties.alignment = .center
        let primaryFont = UIFont.monospacedSystemFont(ofSize: primaryFontSize, weight: .semibold)
        configuration.textProperties.font = UIFontMetrics.default.scaledFont(for: primaryFont)

        configuration.secondaryTextProperties.color = .auxiliaryText
        configuration.secondaryTextProperties.alignment = .center
        configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .footnote)
        configuration.textToSecondaryTextVerticalPadding = verticalSpacing

        configuration.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: verticalSpacing,
            leading: horizontalSpacing,
            bottom: verticalSpacing,
            trailing: horizontalSpacing)
        return configuration
    }()

    private let text: String
    private var columns: Int = 1 {
        didSet {
            if isViewLoaded {
                collectionView.reloadData()
            }
        }
    }
    private var rows: Int = 1
    private let maxSize: CGSize
    private var selectedIndexPath: IndexPath?

    init(text: String, maxSize: CGSize) {
        self.text = text
        self.maxSize = maxSize
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        collectionView.allowsMultipleSelection = false
        collectionView.contentInsetAdjustmentBehavior = .always

        registerCellClasses(collectionView)
        computePreferredSize()
    }

    private func registerCellClasses(_ collectionView: UICollectionView) {
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: CellID.letterCell)
        collectionView.delegate = self
    }

    private func computePreferredSize() {
        let fittingSize = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let size = CGSize(
            width: Int(min(maxSize.width * 0.8, fittingSize.width)),
            height: Int(min(maxSize.height * 0.8, fittingSize.height))
        )
        computeRowsAndColumns(for: size)
        let neededHeight = CGFloat(rows) * cellHeight
        let neededWidth = columns > text.count ? CGFloat(text.count * minimumCellWidth) : size.width
        if columns > text.count {
            columns = text.count
        }
        preferredContentSize = CGSize(width: neededWidth, height: neededHeight)
    }

    private func computeRowsAndColumns(for size: CGSize) {
        columns = Int(size.width) / minimumCellWidth
        rows = Int(ceil(Double(text.count) / Double(columns)))
    }

    func getEstimatedRowCount(atSize size: CGSize) -> Int {
        computePreferredSize()
        return rows
    }

    func detents(for size: CGSize) -> [UISheetPresentationController.Detent] {
        let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("detent")) {
            [unowned self] context in
            self.computeRowsAndColumns(for: self.view.frame.size)
            let neededHeight = ceil(Double(text.count) / Double(columns)) * cellHeight
            return neededHeight < size.height ? neededHeight : size.height * 0.9
        }
        return [customDetent]
    }
}

extension LargeTypeVC {
    override func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        switch section {
        case 0 where rows == 1:
            return text.count
        case rows - 1:
            return text.count - section * columns
        default:
            return columns
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return rows
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellID.letterCell, for: indexPath)
        var configuration = itemCellConfiguration
        let position = indexPath.row + columns * indexPath.section
        let index = text.index(text.startIndex, offsetBy: position)
        configuration.attributedText = PasswordStringHelper.decorate(
            String(text[index]),
            font: configuration.textProperties.font
        )
        configuration.secondaryText = "\(position + 1)"
        cell.contentConfiguration = configuration

        let isPrimaryBackground = {
            if indexPath.section.isMultiple(of: 2) {
                return indexPath.row.isMultiple(of: 2)
            } else {
                return (indexPath.row + 1).isMultiple(of: 2)
            }
        }()
        if indexPath == selectedIndexPath {
            cell.backgroundColor = .actionTint.withAlphaComponent(0.3)
        } else {
            cell.backgroundColor = isPrimaryBackground ? .systemBackground : .secondarySystemBackground
        }
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath == selectedIndexPath {
            selectedIndexPath = nil
        } else {
            selectedIndexPath = indexPath
        }
        collectionView.reloadData()
    }
}

extension LargeTypeVC: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        return 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: view.frame.size.width / Double(columns) - 0.01, height: cellHeight)
    }
}

extension LargeTypeVC: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(
        for controller: UIPresentationController
    ) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerShouldDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) -> Bool {
        return true
    }
}
