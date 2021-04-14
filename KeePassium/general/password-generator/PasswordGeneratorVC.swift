//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class PasswordGeneratorVC: UITableViewController, Refreshable {
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var lengthSlider: UISlider!
    @IBOutlet weak var includeLowerCell: UITableViewCell!
    @IBOutlet weak var includeUpperCell: UITableViewCell!
    @IBOutlet weak var includeSpecialCell: UITableViewCell!
    @IBOutlet weak var includeDigitsCell: UITableViewCell!
    @IBOutlet weak var includeLookAlikeCell: UITableViewCell!

    typealias CompletionHandler = ((String?) -> Void)

    private var password = ""
    private var completionHandler: CompletionHandler?
    
    static func make(completion: CompletionHandler?) -> UIViewController {
        let vc = PasswordGeneratorVC.instantiateFromStoryboard()
        vc.completionHandler = completion
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        loadSettings()
        refresh()
    }

    private func loadSettings() {
        let settings = Settings.current
        
        let length = settings.passwordGeneratorLength
        lengthSlider.value = Float(length)
        lengthLabel.text = "\(length)"
        
        includeLowerCell.accessoryType =
            settings.passwordGeneratorIncludeLowerCase ? .checkmark : .none
        includeUpperCell.accessoryType =
            settings.passwordGeneratorIncludeUpperCase ? .checkmark : .none
        includeSpecialCell.accessoryType =
            settings.passwordGeneratorIncludeSpecials ? .checkmark : .none
        includeDigitsCell.accessoryType =
            settings.passwordGeneratorIncludeDigits ? .checkmark : .none
        includeLookAlikeCell.accessoryType =
            settings.passwordGeneratorIncludeLookAlike ? .checkmark : .none
    }
    
    func refresh() {
        let settings = Settings.current
        var gotChars = false
        var params: Set<PasswordGenerator.Parameters> = []
        if settings.passwordGeneratorIncludeLowerCase {
            params.insert(.includeLowerCase)
            gotChars = true
        }
        if settings.passwordGeneratorIncludeUpperCase {
            params.insert(.includeUpperCase)
            gotChars = true
        }
        if settings.passwordGeneratorIncludeSpecials {
            params.insert(.includeSpecials)
            gotChars = true
        }
        if settings.passwordGeneratorIncludeDigits {
            params.insert(.includeDigits)
            gotChars = true
        }
        if settings.passwordGeneratorIncludeLookAlike {
            params.insert(.includeLookAlike)
        }
        
        guard gotChars else {
            password = ""
            passwordLabel.text = " " 
            return
        }
        
        do {
            password = try PasswordGenerator.generate(
                length: settings.passwordGeneratorLength,
                parameters: params)
            passwordLabel.attributedText = PasswordStringHelper.decorate(
                password,
                font: passwordLabel.font
            )
        } catch {
            Diag.error("RNG error [message: \(error.localizedDescription)]")
            showErrorAlert(error)
        }
    }
    
    
    @IBAction func didChangeLengthSlider(_ sender: Any) {
        let newLength = Int(lengthSlider.value)
        Settings.current.passwordGeneratorLength = newLength
        lengthLabel.text = "\(newLength)"
        refresh()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        
        let settings = Settings.current
        if selectedCell === includeLowerCell {
            settings.passwordGeneratorIncludeLowerCase = !settings.passwordGeneratorIncludeLowerCase
        } else if selectedCell === includeUpperCell {
            settings.passwordGeneratorIncludeUpperCase = !settings.passwordGeneratorIncludeUpperCase
        } else if selectedCell === includeSpecialCell {
            settings.passwordGeneratorIncludeSpecials = !settings.passwordGeneratorIncludeSpecials
        } else if selectedCell === includeDigitsCell {
            settings.passwordGeneratorIncludeDigits = !settings.passwordGeneratorIncludeDigits
        } else if selectedCell === includeLookAlikeCell {
            settings.passwordGeneratorIncludeLookAlike = !settings.passwordGeneratorIncludeLookAlike
        }
        refresh()
        loadSettings()
    }
    
    @IBAction func didPressRefresh(_ sender: Any) {
        refresh()
    }
    
    @IBAction func didPressCancel(_ sender: Any) {
        completionHandler?(nil)
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func didPressDone(_ sender: Any) {
        completionHandler?(password)
        navigationController?.popViewController(animated: true)
    }
}
