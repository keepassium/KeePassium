import KeePassiumLib
import UIKit

protocol DatabaseSettingsDataProtectionVCDelegate: AnyObject {
    func didChangeRememberMasterKey(
        _ rememberMasterKey: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC)
    func didChangeRememberKeyFile(
        _ rememberKeyFile: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC)
    func didChangeRememberDerivedKey(
        _ rememberDerivedKey: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC)
}

final class DatabaseSettingsDataProtectionVC: UITableViewController, Refreshable {
    private enum Cell: Int, CaseIterable {
        case masterKey
        case keyFile
        case derivedKey
    }

    weak var delegate: DatabaseSettingsDataProtectionVCDelegate?

    var rememberMasterKey: Bool? {
        didSet { refresh() }
    }
    var rememberKeyFile: Bool? {
        didSet { refresh() }
    }
    var cachesDerivedEncryptionKey: Bool? {
        didSet { refresh() }
    }

    static func make(delegate: DatabaseSettingsDataProtectionVCDelegate? = nil) -> DatabaseSettingsDataProtectionVC {
        let vc = DatabaseSettingsDataProtectionVC(style: .insetGrouped)
        vc.delegate = delegate
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.estimatedSectionHeaderHeight = 18

        title = LString.titleDataProtectionSettings
        registerCellClasses(tableView)
    }

    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(
            NullableBoolSettingCell.self,
            forCellReuseIdentifier: NullableBoolSettingCell.reuseIdentifier)
    }

    func refresh() {
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Cell.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NullableBoolSettingCell.reuseIdentifier,
            for: indexPath) as! NullableBoolSettingCell

        guard let cellType = Cell(rawValue: indexPath.row) else {
            fatalError("Invalid cell index")
        }

        switch cellType {
        case .masterKey:
            configureMasterKeyCell(cell)
        case .keyFile:
            configureKeyFileCell(cell)
        case .derivedKey:
            configureDerivedKeyCell(cell)
        }
        return cell
    }

    private func configureMasterKeyCell(_ cell: NullableBoolSettingCell) {
        cell.title = LString.titleRememberMasterKey
        cell.value = rememberMasterKey
        cell.defaultValue = Settings.current.isRememberDatabaseKey
        cell.onStateChanged = { [weak self] newValue in
            guard let self = self else { return }

            self.rememberMasterKey = newValue
            self.delegate?.didChangeRememberMasterKey(newValue, in: self)
        }
    }

    private func configureKeyFileCell(_ cell: NullableBoolSettingCell) {
        cell.title = LString.titleRememberKeyFile
        cell.value = rememberKeyFile
        cell.defaultValue = Settings.current.isKeepKeyFileAssociations
        cell.onStateChanged = { [weak self] newValue in
            guard let self = self else { return }

            self.rememberKeyFile = newValue
            self.delegate?.didChangeRememberKeyFile(newValue, in: self)
        }
    }

    private func configureDerivedKeyCell(_ cell: NullableBoolSettingCell) {
        cell.title = LString.titleCacheDerivedKeys
        cell.value = cachesDerivedEncryptionKey
        cell.defaultValue = Settings.current.isRememberDatabaseFinalKey
        cell.onStateChanged = { [weak self] newValue in
            guard let self = self else { return }

            self.cachesDerivedEncryptionKey = newValue
            self.delegate?.didChangeRememberDerivedKey(newValue, in: self)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard #available(iOS 17.4, *),
              let settingCell = tableView.cellForRow(at: indexPath) as? NullableBoolSettingCell
        else {
            return
        }
        settingCell.showMenu()
    }
}

extension LString {
    public static let titleRememberMasterKey = NSLocalizedString(
        "[Database/Settings/DataProtection/RememberMasterKey]",
        value: "Remember Master Key",
        comment: "Setting: whether to keep master key in memory")
    public static let titleRememberKeyFile = NSLocalizedString(
        "[Database/Settings/DataProtection/RememberKeyFile]",
        value: "Remember Key File",
        comment: "Setting: whether to keep key file in memory")
    public static let titleCacheDerivedKeys = NSLocalizedString(
        "[Database/Settings/DataProtection/CacheDerivedKeys]",
        value: "Cache Derived Keys",
        comment: "Setting: whether to keep derived encryption keys in memory")
}
