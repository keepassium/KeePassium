//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol EncryptionSettingsVCDelegate: AnyObject {
    func didPressDismiss(in viewController: EncryptionSettingsVC)
    func didPressDone(in viewController: EncryptionSettingsVC, settings: EncryptionSettings)
}

final class EncryptionSettingsVC: UITableViewController {
    private enum Parameters {
        enum Parallelism {
            static let controlMinimum: Double = 1
            static let controlMaximum: Double = 8
            static func valueToControl(_ parallelism: UInt32) -> Double {
                Double(parallelism)
            }
            static func controlToValue(_ controlValue: Double) -> UInt32 {
                UInt32(controlValue)
            }
        }
        enum Memory {
            static let autoFillWarningThreshold = 32 * 1024 * 1024
            static let controlMinimum: Double = 0
            static let controlMaximum: Double = 8
            static func valueToControl(_ memory: UInt64) -> Double {
                log2(Double(memory / 1024 / 1024))
            }
            static func controlToValue(_ controlValue: Double) -> UInt64 {
                UInt64(pow(2, controlValue)) * 1024 * 1024
            }
        }
        enum Iterations {
            static let controlMinimum: Double = 1
            static let controlMaximum: Double = 82
            static func valueToControl(_ iterations: UInt64) -> Double {
                let order = UInt64(log10(Double(iterations)))
                let position = iterations / UInt64(pow(10, Double(order)))
                let controlValue = Double(order * 9 + position)
                return controlValue
            }
            static func controlToValue(_ controlValue: Double) -> UInt64 {
                var order = Int(controlValue) / 9
                var position = Int(controlValue) % 9
                if position == 0 {
                    order -= 1
                    position = 9
                }
                let orderValue = Int(pow(10, Double(order)))
                let iterations = UInt64(orderValue + (position - 1) * orderValue)
                return iterations
            }
        }
    }

    private enum CellID {
        static let parameterValueCell = "ParameterValueCell"
        static let buttonCell = "ButtonCell"
    }

    private enum Section: Int, CaseIterable {
        case dataCipher
        case kdf
        case buttons
    }

    private enum Cell {
        case dataCipher
        case kdf
        case iterations
        case memory
        case threads

        static func all(for kdf: EncryptionSettings.KeyDerivationFunctionType) -> [Self] {
            switch kdf {
            case .argon2d, .argon2id:
                return [.kdf, .iterations, .memory, .threads]
            case .aesKdf:
                return [.kdf, .iterations]
            }
        }

        var title: String {
            switch self {
            case .dataCipher:
                return LString.encryptionSettingsDataCipher
            case .kdf:
                return LString.encryptionSettingsKDF
            case .iterations:
                return LString.encryptionSettingsIterations
            case .memory:
                return LString.encryptionSettingsMemory
            case .threads:
                return LString.encryptionSettingsThreads
            }
        }
    }


    private lazy var closeButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(didPressDismiss))

    private lazy var doneButton = UIBarButtonItem(
        systemItem: .done,
        primaryAction: UIAction { [weak self] _ in
            self?.didPressDone()
        },
        menu: nil)

    private lazy var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter
    }()

    weak var delegate: EncryptionSettingsVCDelegate?

    private var settings: EncryptionSettings

    init(settings: EncryptionSettings) {
        self.settings = settings
        super.init(style: .insetGrouped)
        tableView.alwaysBounceVertical = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titleEncryptionSettings
        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = doneButton
        tableView.allowsSelection = false

        registerCellClasses(tableView)
    }


    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(
            UINib(nibName: ParameterValueCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: CellID.parameterValueCell)
        tableView.register(
            ButtonCell.classForCoder(),
            forCellReuseIdentifier: CellID.buttonCell)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .dataCipher:
            return 1 // "Encryption algorithm"
        case .kdf:
            return Cell.all(for: settings.kdf).count
        case .buttons:
            return 1 // "Reset to Defaults" button
        case .none:
            fatalError("Invalid section")
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .kdf:
            if let memory = settings.memory,
               memory >= Parameters.Memory.autoFillWarningThreshold
            {
                return String.localizedStringWithFormat(
                    LString.Warning.iconWithMessageTemplate,
                    LString.encryptionMemoryAutoFillWarning
                )
            }
        default:
            break
        }
        return nil
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .dataCipher:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.parameterValueCell,
                for: indexPath)
                as! ParameterValueCell
            let model = Cell.dataCipher
            configure(cell: cell, with: model)
            return cell
        case .kdf:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.parameterValueCell,
                for: indexPath)
                as! ParameterValueCell
            let model = Cell.all(for: settings.kdf)[indexPath.row]
            configure(cell: cell, with: model)
            return cell
        case .buttons:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.buttonCell,
                for: indexPath)
                as! ButtonCell
            let isDefaultSettings = (settings == EncryptionSettings.default)
            cell.button.isEnabled = !isDefaultSettings
            cell.button.configuration?.title = LString.encryptionSettingsReset
            cell.button.contentHorizontalAlignment = .leading
            cell.buttonPressHandler = { [weak self] _ in
                self?.didPressReset()
            }
            return cell
        case .none:
            fatalError("Invalid section")
        }
    }

    private func configure(cell: ParameterValueCell, with model: Cell) {
        cell.textLabel?.text = model.title
        let applyDisclosureIndicator = {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
        }
        let applyMenu = { actions in
            cell.menu = UIMenu(
                title: model.title,
                options: .displayInline,
                children: actions
            )
        }
        let applyStepper = { (stepper: UIStepper) in
            cell.accessoryType = .none
            cell.accessoryView = stepper
            cell.menu = nil
        }

        switch model {
        case .dataCipher:
            cell.detailTextLabel?.text = settings.dataCipher.description
            applyDisclosureIndicator()
            applyMenu(EncryptionSettings.DataCipherType.allCases.map { cipher in
                let action = UIAction(title: cipher.description) { [weak self] _ in
                    self?.settings.dataCipher = cipher
                    self?.validateAndReload()
                }
                action.state = settings.dataCipher == cipher ? .on : .off
                return action
            })
        case .kdf:
            cell.detailTextLabel?.text = settings.kdf.description
            applyDisclosureIndicator()
            applyMenu(EncryptionSettings.KeyDerivationFunctionType.allCases.map { kdf in
                let action = UIAction(title: kdf.description) { [weak self] _ in
                    self?.settings.kdf = kdf
                    self?.validateAndReload()
                }
                action.state = settings.kdf == kdf ? .on : .off
                return action
            })
        case .iterations:
            guard let iterations = settings.iterations else {
                return
            }
            cell.detailTextLabel?.text = numberFormatter.string(from: iterations as NSNumber)
            let stepper = UIStepper()
            stepper.minimumValue = Parameters.Iterations.controlMinimum
            stepper.maximumValue = Parameters.Iterations.controlMaximum
            stepper.value = Parameters.Iterations.valueToControl(iterations)
            stepper.addTarget(self, action: #selector(iterationsValueChanged), for: .valueChanged)
            applyStepper(stepper)
        case .memory:
            guard let memory = settings.memory else {
                return
            }
            cell.detailTextLabel?.text = ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
            let stepper = UIStepper()
            stepper.minimumValue = Parameters.Memory.controlMinimum
            stepper.maximumValue = Parameters.Memory.controlMaximum
            stepper.value = Parameters.Memory.valueToControl(memory)
            stepper.addTarget(self, action: #selector(memoryValueChanged), for: .valueChanged)
            applyStepper(stepper)
        case .threads:
            guard let parallelism = settings.parallelism else {
                return
            }
            cell.detailTextLabel?.text = ThreadCountFormatter.string(fromThreadsCount: parallelism)
            let stepper = UIStepper()
            stepper.minimumValue = Parameters.Parallelism.controlMinimum
            stepper.maximumValue = max(Parameters.Parallelism.controlMaximum, Double(parallelism))
            stepper.value = Parameters.Parallelism.valueToControl(parallelism)
            stepper.addTarget(self, action: #selector(parallelismValueChanged), for: .valueChanged)
            applyStepper(stepper)
        }
    }

    private func validateAndReload() {
        switch settings.kdf {
        case .argon2d, .argon2id:
            if settings.memory == nil {
                settings.memory = EncryptionSettings.default.memory
            }
            if settings.parallelism == nil {
                settings.parallelism = EncryptionSettings.default.parallelism?.magnitude
            }
        case .aesKdf:
            settings.memory = nil
            settings.parallelism = nil
        }
        tableView.reloadData()
    }


    @objc
    private func parallelismValueChanged(stepper: UIStepper) {
        settings.parallelism = Parameters.Parallelism.controlToValue(stepper.value)
        validateAndReload()
    }

    @objc
    private func memoryValueChanged(stepper: UIStepper) {
        settings.memory = Parameters.Memory.controlToValue(stepper.value)
        validateAndReload()
    }

    @objc
    private func iterationsValueChanged(stepper: UIStepper) {
        settings.iterations = Parameters.Iterations.controlToValue(stepper.value)
        validateAndReload()
    }

    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        delegate?.didPressDismiss(in: self)
    }

    private func didPressDone() {
        delegate?.didPressDone(in: self, settings: settings)
    }

    private func didPressReset() {
        settings = .default
        validateAndReload()
    }
}
