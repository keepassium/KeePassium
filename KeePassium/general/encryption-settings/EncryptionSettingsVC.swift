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
            static let argon2RecommendedMinimum = 7 * 1024 * 1024
            static let argon2Baseline = 8 * 1024 * 1024

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
            static let argon2Baseline = 10
            static let argon2Minimum: UInt64 = 1
            static let argon2Maximum: UInt64 = 1000
            static let aesKdfMinimum: UInt64 = 100_000
            static let aesKdfMaximum: UInt64 = 100_000_000

            static func getControlMinimum(kdf: EncryptionSettings.KDFType) -> Double {
                switch kdf {
                case .aesKdf:
                    return valueToControl(aesKdfMinimum)
                case .argon2d, .argon2id:
                    return valueToControl(argon2Minimum)
                }
            }

            static func getControlMaximum(kdf: EncryptionSettings.KDFType) -> Double {
                switch kdf {
                case .aesKdf:
                    return valueToControl(aesKdfMaximum)
                case .argon2d, .argon2id:
                    return valueToControl(argon2Maximum)
                }
            }
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

        static func all(for kdf: EncryptionSettings.KDFType) -> [Self] {
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
    private var sanityWarnings = [String]()

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        validateAndReload()
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
            if sanityWarnings.count > 0 {
                let footer = sanityWarnings.map {
                    String.localizedStringWithFormat(LString.Warning.iconWithMessageTemplate, $0)
                }.joined(separator: "\n")
                return footer
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
            let isDefaultSettings = (settings == EncryptionSettings.defaultSettings())
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
            applyMenu(EncryptionSettings.KDFType.allCases.map { kdf in
                let action = UIAction(title: kdf.description) { [weak self] _ in
                    guard let self else { return }
                    settings.kdf = kdf
                    enforceParameterBounds(&settings)
                    validateAndReload()
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
            stepper.minimumValue = Parameters.Iterations.getControlMinimum(kdf: settings.kdf)
            stepper.maximumValue = Parameters.Iterations.getControlMaximum(kdf: settings.kdf)
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

    private func enforceParameterBounds(_ settings: inout EncryptionSettings) {
        if let iterations = settings.iterations {
            let maxValue = Parameters.Iterations.getControlMaximum(kdf: settings.kdf)
            let minValue = Parameters.Iterations.getControlMinimum(kdf: settings.kdf)
            var controlValue = Parameters.Iterations.valueToControl(iterations)
            if controlValue > maxValue {
                controlValue = maxValue
            } else if controlValue < minValue {
                controlValue = minValue
            }
            settings.iterations = Parameters.Iterations.controlToValue(controlValue)
        }
    }

    private func validateAndReload() {
        sanityWarnings.removeAll()
        let defaults = EncryptionSettings.defaultSettings()
        switch settings.kdf {
        case .argon2d, .argon2id:
            if settings.memory == nil {
                settings.memory = defaults.memory
            }
            if settings.parallelism == nil {
                settings.parallelism = defaults.parallelism?.magnitude
            }
            checkArgon2ParamSanity(&sanityWarnings)
        case .aesKdf:
            settings.memory = nil
            settings.parallelism = nil
            sanityWarnings.append(String.localizedStringWithFormat(
                LString.kdfConsideredWeakTemplate,
                EncryptionSettings.KDFType.aesKdf.description,  // "this is considered weak
                EncryptionSettings.KDFType.argon2id.description //  use this one instead"
            ))
        }
        tableView.reloadData()
    }

    private func checkArgon2ParamSanity(_ warnings: inout [String]) {
        guard let memory = settings.memory,
              let iterations = settings.iterations
        else {
            Diag.warning("One of mandatory parameters is missing.")
            assertionFailure()
            warnings.append("Internal error")
            return
        }

        if memory >= Parameters.Memory.autoFillWarningThreshold {
            warnings.append(LString.encryptionMemoryAutoFillWarning)
        }

        let baseline = Parameters.Memory.argon2Baseline * Parameters.Iterations.argon2Baseline
        let actual = memory * iterations
        let quotient = Float(actual) / Float(baseline)
        if quotient < 0.2 || memory < Parameters.Memory.argon2RecommendedMinimum {
            warnings.append(LString.kdfParametersTooWeak)
        } else if quotient > 64 {
            warnings.append(LString.kdfParametersTooSlow)
        }
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
        settings = .defaultSettings()
        validateAndReload()
    }
}

// swiftlint:disable line_length
extension LString {
    public static let kdfConsideredWeakTemplate = NSLocalizedString(
        "[Database/KDF/consideredWeak]",
        value: "%@ is considered weak. Use %@ instead.",
        comment: "Warning that one key derivation function (KDF) should be preferred to another. Example: 'AES-KDF is considered weak. Use Argon2id instead.'")
    public static let kdfParametersTooWeak = NSLocalizedString(
        "[Database/KDF/tooWeak]",
        value: "Increase the settings for optimal data protection.",
        comment: "Call to action when encryption settings are too weak.")
    public static let kdfParametersTooSlow = NSLocalizedString(
        "[Database/KDF/tooSlow]",
        value: "These settings may be too slow for some devices.",
        comment: "Notification message about encryption settings.")
}
// swiftlint:enable line_length
