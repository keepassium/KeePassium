//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AVFoundation
import KeePassiumLib
import UIKit

final class QRCodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var backdropColor: UIColor {
        UIAccessibility.isReduceTransparencyEnabled
            ? UIColor.black
            : UIColor.black.withAlphaComponent(0.7)
    }

    var completion: QRCodeScanner.Completion?

    private lazy var instructionContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backdropColor
        view.isHidden = true
        return view
    }()

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = LString.qrScannerCallToAction
        label.textColor = .lightText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var dismissButton: UIButton = {
        var buttonConfig = UIButton.Configuration.gray()
        buttonConfig.title = LString.actionDismiss
        buttonConfig.buttonSize = .large
        let button = UIButton(configuration: buttonConfig)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(dismissScanner), for: .touchUpInside)
        return button
    }()

    private lazy var permissionDeniedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backdropColor
        view.isHidden = true
        return view
    }()

    private lazy var permissionDeniedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = LString.qrScannerCameraPermissionDescription
        label.textColor = .lightText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var openSettingsButton: UIButton = {
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = LString.actionOpenSystemSettings
        buttonConfig.image = UIImage.symbol(.gear)
        buttonConfig.imagePadding = 8
        buttonConfig.buttonSize = .medium
        buttonConfig.cornerStyle = .dynamic
        let button = UIButton(configuration: buttonConfig)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openPermissionsSettings), for: .touchUpInside)
        return button
    }()

    private let dismissCommand = UIKeyCommand(
        input: UIKeyCommand.inputEscape,
        modifierFlags: [],
        action: #selector(dismissScanner)
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCommonUIElements()
        checkPermissionsAndSetupScanner()
        addKeyCommand(dismissCommand)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.async { [weak self] in
            self?.startCaptureSession()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }

    deinit {
        Diag.debug("QR Scanner deallocated")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let previewLayer else { return }

        let frameChanged = !previewLayer.frame.equalTo(view.layer.bounds)
        if !frameChanged {
            return
        }

        previewLayer.frame = view.layer.bounds
        updatePreviewOrientation()
    }

    private func setupCommonUIElements() {
        view.addSubview(dismissButton)
        view.addSubview(instructionContainerView)
        instructionContainerView.addSubview(instructionLabel)
        view.addSubview(permissionDeniedContainer)
        permissionDeniedContainer.addSubview(permissionDeniedLabel)
        permissionDeniedContainer.addSubview(openSettingsButton)

        let safeArea = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            instructionContainerView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            instructionContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            instructionContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            instructionLabel.topAnchor.constraint(equalTo: instructionContainerView.topAnchor, constant: 16),
            instructionLabel.leadingAnchor.constraint(equalTo: instructionContainerView.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: instructionContainerView.trailingAnchor, constant: -16),
            instructionLabel.bottomAnchor.constraint(equalTo: instructionContainerView.bottomAnchor, constant: -16),

            permissionDeniedContainer.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            permissionDeniedContainer.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            permissionDeniedContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            permissionDeniedLabel.leadingAnchor.constraint(
                equalTo: permissionDeniedContainer.leadingAnchor, constant: 16),
            permissionDeniedLabel.trailingAnchor.constraint(
                equalTo: permissionDeniedContainer.trailingAnchor, constant: -16),
            permissionDeniedLabel.topAnchor.constraint(equalTo: permissionDeniedContainer.topAnchor),

            openSettingsButton.leadingAnchor.constraint(greaterThanOrEqualTo: permissionDeniedContainer.leadingAnchor),
            openSettingsButton.trailingAnchor.constraint(lessThanOrEqualTo: permissionDeniedContainer.trailingAnchor),
            openSettingsButton.topAnchor.constraint(equalTo: permissionDeniedLabel.bottomAnchor, constant: 16),
            openSettingsButton.centerXAnchor.constraint(equalTo: permissionDeniedContainer.centerXAnchor),
            openSettingsButton.bottomAnchor.constraint(equalTo: permissionDeniedContainer.bottomAnchor),

            dismissButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            dismissButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            dismissButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
        ])
    }

    private func checkPermissionsAndSetupScanner() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.configureForAuthorizedState()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureForAuthorizedState()
                    } else {
                        self.configureForDeniedState()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.configureForDeniedState()
            }
        @unknown default:
            DispatchQueue.main.async {
                self.configureForDeniedState()
                Diag.error("Unknown camera authorization status [status: \(status)]")
            }
        }
    }

    private func configureForAuthorizedState() {
        permissionDeniedContainer.isHidden = true
        instructionContainerView.isHidden = false

        if captureSession == nil {
            setupCaptureSession()
        }

        if let previewLayer = self.previewLayer, previewLayer.superlayer == nil {
            view.layer.insertSublayer(previewLayer, at: 0)
            previewLayer.frame = view.layer.bounds
            updatePreviewOrientation()
        }

        if let session = captureSession, !session.isRunning {
             startCaptureSession()
        }
    }

    private func configureForDeniedState() {
        stopCaptureSession()

        previewLayer?.removeFromSuperlayer()
        instructionContainerView.isHidden = true
        permissionDeniedContainer.isHidden = false
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            Diag.error("No suitable video capture device found.")
            showError(.imageSourceNotAvailable)
            return
        }

        Diag.debug("Selected video capture device: \(videoCaptureDevice.localizedName) [Type: \(videoCaptureDevice.deviceType.rawValue), Position: \(videoCaptureDevice.position.rawValue)]")

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            guard captureSession.canAddInput(videoInput) else {
                Diag.error("Cannot add video capture input, cancelling.")
                showError(.cameraBusy)
                return
            }
            captureSession.addInput(videoInput)
        } catch {
            Diag.error("Failed to create video capture input [message: \(error.localizedDescription)]")
            showError(.other(error))
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            Diag.error("Cannot add video capture output, cancelling.")
            showError(.cameraBusy)
            return
        }

        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
    }

    private func startCaptureSession() {
        guard let session = captureSession else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized = (status == .authorized)

        if authorized && !session.isRunning {
            updatePreviewOrientation()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }

    private func stopCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    @objc private func dismissScanner() {
        assert(Thread.isMainThread)
        completion?(.success(nil))
    }

    @objc private func openPermissionsSettings() {
        URLOpener(self).open(url: URL.Prefs.cameraPermissionsURL)
    }

    private func showError(_ error: QRScannerError) {
        assert(Thread.isMainThread)
        let alert = UIAlertController(
            title: LString.titleError,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LString.actionOK, style: .default) { [weak self] _ in
            self?.completion?(.failure(error))
        })

        present(alert, animated: true)
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else {
            return
        }

        guard connection.isVideoRotationAngleSupported(0) else {
            return
        }

        let deviceOrientation = UIDevice.current.orientation
        let rotationAngle: CGFloat

        switch deviceOrientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 0
        case .landscapeRight:
            rotationAngle = 180
        case .faceUp, .faceDown, .unknown:
            return
        @unknown default:
            return
        }

        connection.videoRotationAngle = rotationAngle
    }
}

extension QRCodeScannerVC {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        stopCaptureSession()

        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue
        else { return }

        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        HapticFeedback.play(.qrCodeScanned)

        assert(Thread.isMainThread)
        completion?(.success(stringValue))
    }
}
