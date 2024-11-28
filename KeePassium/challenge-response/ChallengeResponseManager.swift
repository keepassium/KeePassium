//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
#if !targetEnvironment(macCatalyst)
import YubiKit
#endif

private let YUBIKEY_SUCCESS: UInt16 = 0x9000
private let YUBIKEY_MFI_TOUCH_TIMEOUT: UInt16 = 0x6985
private let YUBIKEY_OTP_DISABLED: UInt16 = 0x6A82

class ChallengeResponseManager {
    static let instance = ChallengeResponseManager()

    private var accessorySessionStateObservation: NSKeyValueObservation?
    private var nfcSessionStateObservation: NSKeyValueObservation?

    public private(set) var supportsNFC = false
    public private(set) var supportsMFI = false
    public private(set) var supportsMFIoverUSB = false
    public private(set) var supportsUSB = false

    private var mfiKeyActionSheetView: MFIKeyActionSheetView? 

    private var challenge: SecureBytes?
    private var responseHandler: ResponseHandler?
    private var currentKey: YubiKey?
    private var isResponseSent = false

    private var queue: DispatchQueue
    private var usbYubiKey: YubiKeyUSB?
    private weak var sheetPresenter: UIView?

    private init() {
        queue = DispatchQueue(label: "ChallengeResponseManager")
        initSessionObservers()
    }

    deinit {
        accessorySessionStateObservation = nil
        nfcSessionStateObservation = nil
    }

    public static func makeHandler(for yubiKey: YubiKey?, presenter: UIView) -> ChallengeHandler? {
        guard let yubiKey = yubiKey else {
            Diag.debug("Challenge-response is not used")
            return nil
        }

        var topPresenter = presenter
        while topPresenter.superview != nil {
            topPresenter = topPresenter.superview!
        }
        let challengeHandler: ChallengeHandler = { [weak topPresenter] challenge, responseHandler in
            instance.perform(
                with: yubiKey,
                challenge: challenge,
                presenter: topPresenter,
                responseHandler: responseHandler
            )
        }
        return challengeHandler
    }


    private func initSessionObservers() {
        #if targetEnvironment(macCatalyst)
        supportsMFIoverUSB = false
        supportsMFI = false
        supportsNFC = false
        #else
        supportsMFIoverUSB = YubiKitDeviceCapabilities.supportsMFIOverUSBC
        supportsMFI = YubiKitDeviceCapabilities.supportsMFIAccessoryKey
        if supportsMFI {
            initMFISessionObserver()
        }
        supportsNFC = YubiKitDeviceCapabilities.supportsISO7816NFCTags
        if supportsNFC {
            initNFCSessionObserver()
        }
        #endif

        supportsUSB = YubiKeyUSB.isSupported
    }

    private func initMFISessionObserver() {
        #if !targetEnvironment(macCatalyst)
        let accessorySession = YubiKitManager.shared.accessorySession as! YKFAccessorySession
        accessorySessionStateObservation = accessorySession.observe(
            \.sessionState,
            changeHandler: { [weak self] _, _ in
                self?.accessorySessionStateDidChange()
            }
        )
        #endif
    }

    private func initNFCSessionObserver() {
        #if !targetEnvironment(macCatalyst)
        let nfcSession = YubiKitManager.shared.nfcSession as! YKFNFCSession
        nfcSessionStateObservation = nfcSession.observe(
            \.iso7816SessionState,
            changeHandler: { [weak self] _, _ in
                self?.nfcSessionStateDidChange()
            }
        )
        #endif
    }


#if !targetEnvironment(macCatalyst)
    private func accessorySessionStateDidChange() {
        let keySession = YubiKitManager.shared.accessorySession as! YKFAccessorySession
        switch keySession.sessionState {
        case .opening:
            print("Accessory session -> opening")
        case .open:
            print("Accessory session -> open")
            queue.async { [weak self] in
                guard let self = self else { return }
                guard let key = self.currentKey else { assertionFailure(); return }
                self.presentMFIActionSheet(
                    state: .touchKey,
                    message: LString.touchMFIYubikey,
                    delay: 0.7,
                    completion: { }
                )
                self.performChallengeResponse(keySession, slot: key.slot)
                keySession.stopSessionSync()
            }
        case .closing:
            print("Accessory session -> closing")
        case .closed:
            print("Accessory session -> closed")
            keySession.cancelCommands()
            dismissMFIActionSheet(delayed: false, completion: { })
            if !isResponseSent {
                returnError(.cancelled)
            }
        @unknown default:
            fatalError()
        }
    }

    private func nfcSessionStateDidChange() {
        let keySession = YubiKitManager.shared.nfcSession as! YKFNFCSession
        switch keySession.iso7816SessionState {
        case .open:
            print("NFC session -> open")
            queue.async { [weak self] in
                guard let key = self?.currentKey else { assertionFailure(); return }
                self?.performChallengeResponse(keySession, slot: key.slot)
                keySession.stopIso7816Session()
            }
        case .pooling:
            print("NFC session -> pooling")
        case .closed:
            print("NFC session -> closed")
            if !isResponseSent {
                returnError(.cancelled)
            }
        @unknown default:
            assertionFailure()
        }
    }
#endif


    private func perform(
        with yubiKey: YubiKey,
        challenge: SecureBytes,
        presenter: UIView?,
        responseHandler: @escaping ResponseHandler
    ) {
        self.challenge = challenge.clone()
        self.responseHandler = responseHandler
        self.sheetPresenter = presenter

        isResponseSent = false
        switch yubiKey.interface {
        case .nfc:
            startNFCSession(with: yubiKey, challenge: challenge, responseHandler: responseHandler)
        case .mfi:
            startMFISession(with: yubiKey, challenge: challenge, responseHandler: responseHandler)
        case .usb:
            startUSBSession(with: yubiKey, challenge: challenge, responseHandler: responseHandler)
        }
    }

    private func returnResponse(_ response: SecureBytes) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.responseHandler?(response, nil)
            self.isResponseSent = true
            self.cancel()
        }
    }

    private func returnError(_ error: ChallengeResponseError) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.responseHandler?(SecureBytes.empty(), error)
            self.isResponseSent = true
            self.cancel()
        }
    }


    private func startMFISession(
        with yubiKey: YubiKey,
        challenge: SecureBytes,
        responseHandler: @escaping ResponseHandler
    ) {
        #if !targetEnvironment(macCatalyst)
        guard supportsMFI else {
            returnError(.notSupportedByDeviceOrSystem(interface: yubiKey.interface.description))
            return
        }
        currentKey = yubiKey
        let keySession = YubiKitManager.shared.accessorySession
        keySession.startSession()
        if !keySession.isKeyConnected {
            presentMFIActionSheet(
                state: .insertKey,
                message: LString.insertMFIYubikey,
                completion: { }
            )
        }
        #endif
    }

    private func startNFCSession(
        with yubiKey: YubiKey,
        challenge: SecureBytes,
        responseHandler: @escaping ResponseHandler
    ) {
        #if !targetEnvironment(macCatalyst)
        guard supportsNFC else {
            #if AUTOFILL_EXT
            returnError(.notAvailableInAutoFill)
            #else
            returnError(.notSupportedByDeviceOrSystem(interface: yubiKey.interface.description))
            #endif
            return
        }
        currentKey = yubiKey
        let nfcSession = YubiKitManager.shared.nfcSession as! YKFNFCSession
        Watchdog.shared.ignoreMinimizationOnce()
        nfcSession.startIso7816Session()
        #endif
    }

    private func startUSBSession(
        with yubiKey: YubiKey,
        challenge: SecureBytes,
        responseHandler: @escaping ResponseHandler
    ) {
        guard supportsUSB else {
            #if AUTOFILL_EXT
            returnError(.notAvailableInAutoFill)
            #else
            returnError(.notSupportedByDeviceOrSystem(interface: yubiKey.interface.description))
            #endif
            return
        }
        #if !targetEnvironment(macCatalyst)
        assertionFailure("Unexpected USB YubiKey support on non-Catalyst platform")
        #else
        currentKey = yubiKey
        let connectedKeys = YubiKeyUSB.getConnectedKeys()
        guard connectedKeys.count > 0 else {
            returnError(.keyNotConnected)
            return
        }
        guard let otpEnabledKey = connectedKeys.first(where: { $0.isOTPEnabled }) else {
            returnError(.keyNotConfigured)
            return
        }

        let commandSlot: YubiKeyUSB.ConfigSlot
        switch yubiKey.slot {
        case .slot1:
            commandSlot = .chalHMAC1
        case .slot2:
            commandSlot = .chalHMAC2
        }
        do {
            try otpEnabledKey.open() 
            usbYubiKey = otpEnabledKey
            defer {
                otpEnabledKey.close()
            }

            presentMFIActionSheet(
                state: .processing,
                message: LString.touchMFIYubikey,
                delay: 0.25,
                completion: { }
            )
            let response = try challenge.withDecryptedData { challengeData in
                try otpEnabledKey.performChallengeResponse(
                    slot: commandSlot,
                    challenge: challengeData,
                    observer: { status in
                        print("YK status: \(status)")
                    }
                )
            }
            dismissMFIActionSheet(delayed: false)
            returnResponse(SecureBytes.from(response))
        } catch let error as YubiKeyUSB.Error {
            dismissMFIActionSheet(delayed: false)
            switch error {
            case .slotNotConfigured:
                returnError(.keyNotConfigured)
            case .communicationFailure,
                 .responseTimeout:
                returnError(.communicationError(message: error.localizedDescription))
            case .cancelled,
                 .touchTimeout:
                returnError(.cancelled)
            }
        } catch {
            assertionFailure("Unexpected error type")
            Diag.error("Unexpected YubiKey error [message: \(error.localizedDescription)]")
            returnError(.cancelled)
        }
        #endif
    }

    private func cancel() {
        guard let currentKey = currentKey else {
            challenge?.erase()
            responseHandler = nil
            return
        }

        switch currentKey.interface {
        case .mfi:
            cancelMFISession()
        case .nfc:
            cancelNFCSession()
        case .usb:
            cancelUSBSession()
        }
        challenge?.erase()
        responseHandler = nil
        self.currentKey = nil
    }

    private func cancelMFISession() {
        #if !targetEnvironment(macCatalyst)
        let accessorySession = YubiKitManager.shared.accessorySession
        if accessorySession.sessionState == .opening || accessorySession.sessionState == .open {
            accessorySession.stopSession()
        } else {
            accessorySession.cancelCommands()
        }
        #endif
    }

    private func cancelNFCSession() {
        #if !targetEnvironment(macCatalyst)
        let nfcSession = YubiKitManager.shared.nfcSession
        nfcSession.cancelCommands()
        nfcSession.stopIso7816Session()
        #endif
    }

    private func cancelUSBSession() {
        #if targetEnvironment(macCatalyst)
        usbYubiKey?.cancel()
        usbYubiKey = nil
        #endif
    }


    private class RawResponseParser {
        private var response: Data

        init(response: Data) {
            self.response = response
        }

        var statusCode: UInt16 {
            guard response.count >= 2 else {
                return 0
            }
            return UInt16(response[response.count - 2]) << 8 + UInt16(response[response.count - 1])
        }

        var responseData: Data? {
            guard response.count > 2 else {
                return nil
            }
            return response.subdata(in: 0..<response.count - 2)
        }
    }

#if !targetEnvironment(macCatalyst)
    private func performChallengeResponse(
        _ accessorySession: YKFAccessorySession,
        slot: YubiKey.Slot
    ) {
        assert(accessorySession.sessionState == .open)
        let keyName = accessorySession.accessoryDescription?.name ?? "(unknown)"
        Diag.info("Connecting to \(keyName)")
        guard let rawCommandService = accessorySession.rawCommandService else {
            let message = "YubiKey raw command service is not available"
            Diag.error(message)
            returnError(.communicationError(message: message))
            return
        }
        performChallengeResponse(rawCommandService: rawCommandService, slot: slot)
    }

    private func performChallengeResponse(
        _ nfcSession: YKFNFCSession,
        slot: YubiKey.Slot
    ) {
        assert(nfcSession.iso7816SessionState == .open)
        let keyName = nfcSession.tagDescription?.identifier.description ?? "(unknown)"
        Diag.info("Found NFC tag \(keyName)")
        guard let rawCommandService = nfcSession.rawCommandService else {
            let message = "YubiKey raw command service is not available"
            Diag.error(message)
            returnError(.communicationError(message: message))
            return
        }
        performChallengeResponse(rawCommandService: rawCommandService, slot: slot)
    }

    private func performChallengeResponse(
        rawCommandService: YKFKeyRawCommandServiceProtocol,
        slot: YubiKey.Slot
    ) {
        let appletID = Data([0xA0, 0x00, 0x00, 0x05, 0x27, 0x20, 0x01])
        guard let selectAppletAPDU =
            YKFAPDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0x00, data: appletID, type: .short)
            else { fatalError() }

        rawCommandService.executeSyncCommand(selectAppletAPDU) { [weak self] response, error in
            guard let self = self else { return }
            if let error = error {
                Diag.error("YubiKey select applet failed [message: \(error.localizedDescription)]")
                self.returnError(.communicationError(message: error.localizedDescription))
                return
            }

            let responseParser = RawResponseParser(response: response!)
            let statusCode = responseParser.statusCode
            switch statusCode {
            case YUBIKEY_SUCCESS:
                guard responseParser.responseData != nil else {
                    let message = "YubiKey response is empty"
                    Diag.error(message)
                    self.returnError(.communicationError(message: message))
                    return
                }
            case YUBIKEY_OTP_DISABLED:
                Diag.error("YubiKey has OTP function disabled for this interface, returned code \(String(format: "%04X", statusCode))")
                self.returnError(.keyNotConfigured)
            default:
                let message = "YubiKey select applet failed with code 0x\(String(format: "%04X", statusCode))"
                Diag.error(message)
                self.returnError(.communicationError(message: message))
            }
        }

        guard var challengeBytes = challenge?.withDecryptedBytes({ $0.clone() }),
              challengeBytes.count <= 64
        else {
            fatalError()
        }
        defer {
            challengeBytes.erase()
        }

        let paddingLength = 64 - challengeBytes.count
        let pkcs7padding: [UInt8] = Array(repeating: UInt8(paddingLength), count: paddingLength)
        challengeBytes.append(contentsOf: pkcs7padding)
        var challengeData = Data(challengeBytes)
        defer {
            challengeData.erase()
        }

        let slotID = getSlotID(for: slot)
        guard let chalRespAPDU =
            YKFAPDU(cla: 0x00, ins: 0x01, p1: slotID, p2: 0x00, data: challengeData, type: .short)
            else { fatalError() }

        rawCommandService.executeSyncCommand(chalRespAPDU) { [weak self] response, error in
            guard let self = self else { return }
            if let error = error {
                Diag.error("YubiKey error while executing command [message: \(error.localizedDescription)]")
                self.returnError(.communicationError(message: error.localizedDescription))
                return
            }

            let responseParser = RawResponseParser(response: response!)
            let statusCode = responseParser.statusCode
            switch statusCode {
            case YUBIKEY_SUCCESS:
                guard let responseData = responseParser.responseData else {
                    let message = "YubiKey response is empty. Slot not configured?"
                    Diag.error(message)
                    self.returnError(.keyNotConfigured)
                    return
                }
                let response = SecureBytes.from(responseData)
                self.returnResponse(response)
            case YUBIKEY_MFI_TOUCH_TIMEOUT:
                Diag.error("YubiKey touch timeout")
                self.returnError(.cancelled)
            default:
                let message = "YubiKey challenge failed with code \(String(format: "%04X", statusCode))"
                Diag.error(message)
                self.returnError(.communicationError(message: message))
            }
        }
    }
#endif

    private func getSlotID(for slot: YubiKey.Slot) -> UInt8 {
        switch slot {
        case .slot1:
            return 0x30
        case .slot2:
            return 0x38
        }
    }


    enum MFIKeyInteractionViewState {
        case insertKey
        case touchKey
        case processing
    }

    private func presentMFIActionSheet(
        state: MFIKeyInteractionViewState,
        message: String,
        delay: TimeInterval = 0.0,
        completion: @escaping () -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.mfiKeyActionSheetView == nil else {
                self.setMFIActionSheet(state: state, message: message)
                completion()
                return
            }
            self.mfiKeyActionSheetView = MFIKeyActionSheetView.loadViewFromNib()
            guard let actionSheet = self.mfiKeyActionSheetView,
                  let sheetPresenter = sheetPresenter
            else {
                Diag.error("Internal error, cannot present YubiKey dialog. Cancelling")
                assertionFailure()
                return
            }
            actionSheet.delegate = self
            actionSheet.frame = sheetPresenter.bounds
            sheetPresenter.addSubview(actionSheet)
            actionSheet.present(animated: true, delay: delay, completion: completion)
            self.setMFIActionSheet(state: state, message: message)
        }
    }

    private func dismissMFIActionSheet(delayed: Bool, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let actionSheet = self.mfiKeyActionSheetView else {
                completion()
                return
            }
            actionSheet.dismiss(animated: true, delayed: delayed) { [weak self] in
                guard let self = self else { return }
                self.mfiKeyActionSheetView?.removeFromSuperview()
                self.mfiKeyActionSheetView = nil
                completion()
            }
        }
    }

    private func setMFIActionSheet(state: MFIKeyInteractionViewState, message: String) {
        guard let actionSheet = mfiKeyActionSheetView else { return }
        switch state {
        case .insertKey:
            actionSheet.animateInsertKey(message: message)
        case .touchKey:
            actionSheet.animateTouchKey(message: message)
        case .processing:
            actionSheet.animateProcessing(message: message)
        }
    }
}

extension ChallengeResponseManager: MFIKeyActionSheetViewDelegate {
    func mfiKeyActionSheetDidDismiss(_ actionSheet: MFIKeyActionSheetView) {
        cancelUSBSession()
        dismissMFIActionSheet(delayed: false) { [weak self] in
            self?.returnError(.cancelled)
        }
    }
}
