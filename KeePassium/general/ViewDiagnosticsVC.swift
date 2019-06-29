//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class DiagItemCell: UITableViewCell {
    fileprivate static let storyboardID = "DiagItemCell"
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var levelImage: UIImageView!
    
    func fillData(from item: Diag.Item) {
        placeLabel?.text = "\(item.file):\(item.line)\n\(item.function)"
        messageLabel?.text = item.message
        levelImage.image = UIImage(named: item.level.imageName)
    }
}

extension Diag.Level {
    var imageName: String {
        switch self {
        case .verbose:
            return "diag-level-verbose"
        case .debug:
            return "diag-level-debug"
        case .info:
            return "diag-level-info"
        case .warning:
            return "diag-level-warning"
        case .error:
            return "diag-level-error"
        }
    }
}

class ViewDiagnosticsVC: UITableViewController, Refreshable {
    @IBOutlet private weak var textView: UITextView!
    private var items: [Diag.Item] = []
    
    static func make() -> UIViewController {
        let vc = ViewDiagnosticsVC.instantiateFromStoryboard()
        let navVC = UINavigationController(rootViewController: vc)
        navVC.isToolbarHidden = false
        navVC.modalPresentationStyle = .formSheet
        return navVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        refresh()
    }
    
    func refresh() {
        items = Diag.itemsSnapshot()
        tableView.reloadData()
        if items.count > 0 {
            let lastRowIndexPath = IndexPath(row: items.count - 1, section: 0)
            DispatchQueue.main.async { 
                self.tableView.scrollToRow(at: lastRowIndexPath, at: .none, animated: true)
            }
        }
    }
    
    @IBAction func didPressCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didPressCompose(_ sender: Any) {
        SupportEmailComposer.show(includeDiagnostics: true) {
            [weak self] (success) in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func didPressClear(_ sender: Any) {
        Diag.clear()
        refresh()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DiagItemCell.storyboardID,
            for: indexPath)
            as! DiagItemCell
        cell.fillData(from: item)
        return cell
    }
}

