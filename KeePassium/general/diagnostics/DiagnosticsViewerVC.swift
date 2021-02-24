//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class DiagnosticsViewerCell: UITableViewCell {
    static let storyboardID = "DiagnosticsViewerCell"
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var levelImage: UIImageView!
    
    func setDiagItem(_ item: Diag.Item) {
        placeLabel?.text = "\(item.file):\(item.line)\n\(item.function)"
        messageLabel?.text = item.message
        levelImage.image = imageForLevel(item.level)
    }
    
    func imageForLevel(_ level: Diag.Level) -> UIImage? {
        switch level {
        case .verbose:
            return UIImage(named: "diag-level-verbose")
        case .debug:
            return UIImage(named: "diag-level-debug")
        case .info:
            return UIImage(named: "diag-level-info")
        case .warning:
            return UIImage(named: "diag-level-warning")
        case .error:
            return UIImage(named: "diag-level-error")
        }
    }
}

protocol DiagnosticsViewerDelegate: class {
    func didPressCopy(in diagnosticsViewer: DiagnosticsViewerVC, text: String)
    func didPressContactSupport(in diagnosticsViewer: DiagnosticsViewerVC, text: String)
}

class DiagnosticsViewerVC: UITableViewController, Refreshable {
    private var items: [Diag.Item] = [] {
        didSet {
            refresh()
        }
    }

    @IBOutlet weak var copyButton: UIBarButtonItem!
    @IBOutlet weak var contactButton: UIBarButtonItem!
    
    weak var delegate: DiagnosticsViewerDelegate?
    
    public static func create() -> DiagnosticsViewerVC {
        return DiagnosticsViewerVC.instantiateFromStoryboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        items = Diag.itemsSnapshot()

        contactButton.title = LString.actionContactSupport
        copyButton.accessibilityLabel = LString.actionCopy
        
        refresh()
        if items.count > 0 {
            let lastRowIndexPath = IndexPath(row: items.count - 1, section: 0)
            DispatchQueue.main.async { 
                self.tableView.scrollToRow(at: lastRowIndexPath, at: .none, animated: true)
            }
        }
    }
    
    func refresh() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }
    
    
    @IBAction func didPressCopy(_ sender: Any) {
        Watchdog.shared.restart()
        let logText = Diag.toString()
        delegate?.didPressCopy(in: self, text: logText)
    }
    
    @IBAction func didPressContactSupport(_ sender: Any) {
        Watchdog.shared.restart()
        let logText = Diag.toString()
        delegate?.didPressContactSupport(in: self, text: logText)
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
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DiagnosticsViewerCell.storyboardID,
            for: indexPath)
            as! DiagnosticsViewerCell
        cell.setDiagItem(items[indexPath.row])
        return cell
    }
}
