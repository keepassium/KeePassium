//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

#if targetEnvironment(macCatalyst)
import Foundation
import IOKit.hid
#endif
import KeePassiumLib

class YubiKeyUSB {

    public enum ConfigSlot: UInt8 {
        case deviceSerial = 0x10 
        case chalHMAC1 = 0x30  
        case chalHMAC2 = 0x38  
    }

    public typealias YubiKeyStateObserver = (YubiKeyState) -> Void
    public enum YubiKeyState {
        case waitingForTouch
        case processing
    }

    public static var isSupported: Bool {
        guard ProcessInfo.isCatalystApp else {
            return false
        }
        #if MAIN_APP
        return true
        #elseif AUTOFILL_EXT
        return false // app extension cannot get "input monitoring" permission
        #endif
    }

#if targetEnvironment(macCatalyst)
    public enum Error: LocalizedError {
        case cancelled
        case communicationFailure
        case slotNotConfigured
        case responseTimeout
        case touchTimeout

        public var errorDescription: String? {
            switch self {
            case .cancelled:
                return "Cancelled by the user."
            case .communicationFailure:
                return "Failed to communicate with the YubiKey."
            case .slotNotConfigured:
                return "Slot is not configured."
            case .responseTimeout:
                return "Timeout waiting for YubiKey response."
            case .touchTimeout:
                return "Timeout waiting for YubiKey touch."
            }
        }
    }

    private enum HIDLayer {
        static let featureReportSize = 8
        static let featureReportDataSize = featureReportSize - 1
    }

    private enum YubiKeyLayer {
        static let YubicoVendorID = 0x1050
        static let YubicoOTPUsage = (1, 6)

        static let majorVersionOffset = 0x01
        static let minorVersionOffset = 0x02
        static let buildVersionOffset = 0x03
        static let configSequenceOffset = 0x04
        static let touchLowOffset = 0x05

        static let configStatusMask = UInt8(0x1F)

        static let slotDataSize = 64
        enum StatusFlags {
            static let timeoutWait = UInt8(0x20) 
            static let pending = UInt8(0x40)  
            static let slotWrite = UInt8(0x80)  

            static let sequenceMask = UInt8(0x1F)
        }
        static let crcValidResidue = UInt16(0xF0B8)

        static let hmacChallengeSize = 64
        static let hmacResponseSize = 20
    }

    public let isOTPEnabled: Bool

    private var hidDevice: IOHIDDevice
    private var isDeviceOpen = false
    private var isCancelled = false

    private init(hidDevice: IOHIDDevice, isOTPEnabled: Bool) {
        self.hidDevice = hidDevice
        self.isOTPEnabled = isOTPEnabled
    }

    public static func getConnectedKeys() -> [YubiKeyUSB] {
        let hidManager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        let filterDict = [kIOHIDVendorIDKey as CFString: YubiKeyLayer.YubicoVendorID]
        IOHIDManagerSetDeviceMatching(hidManager, filterDict as CFDictionary)
        guard let deviceCFSet = IOHIDManagerCopyDevices(hidManager),
              let deviceSet = deviceCFSet as? Set<IOHIDDevice>
        else {
            Diag.debug("Failed to get YubiKey USB devices")
            return []
        }

        var yubiKeyDevices = [YubiKeyUSB]()
        let hidDevices = Array(deviceSet)
        for hidDevice in hidDevices {
            let vendorID = hidDevice.getVendorID()
            assert(vendorID == YubiKeyLayer.YubicoVendorID)
            let productID = hidDevice.getProductID()
            let productName = hidDevice.getProductName()
            let primaryUsage = hidDevice.getPrimaryUsagePair()
            Diag.debug(String(
                format: "Found %@ [PID: %04x, HID usage: (%X, %X)]",
                productName,
                productID,
                primaryUsage.0, primaryUsage.1)
            )
            let isOTPEnabled = (primaryUsage == YubiKeyLayer.YubicoOTPUsage)
            let yubiKeyDevice = YubiKeyUSB(hidDevice: hidDevice, isOTPEnabled: isOTPEnabled)
            yubiKeyDevices.append(yubiKeyDevice)
        }
        return yubiKeyDevices
    }


    public func open() throws {
        guard !isDeviceOpen else {
            assertionFailure("Device is already opened, ignoring")
            return
        }
        let result = IOHIDDeviceOpen(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            Diag.error("Failed to open USB HID device [code: \(result)]")
            throw Error.communicationFailure
        }
        isDeviceOpen = true
        isCancelled = false
        Diag.debug("USB HID device opened")
    }

    public func close() {
        guard isDeviceOpen else {
            assertionFailure("Tried to close already closed device, ignoring")
            return
        }
        IOHIDDeviceClose(hidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        isDeviceOpen = false
        isCancelled = false
        Diag.debug("USB HID device closed")
    }

    private func send(_ packet: Data) throws {
        guard isDeviceOpen else {
            Diag.warning("USB HID device must be opened")
            throw Error.communicationFailure
        }
        let result: IOReturn = packet.withUnsafeBytes {
            let bytes = $0.bindMemory(to: UInt8.self).baseAddress!
            return IOHIDDeviceSetReport(hidDevice, kIOHIDReportTypeFeature, 0, bytes, packet.count)
        }
        guard result == kIOReturnSuccess else {
            Diag.warning("Failed to send to USB HID device [code: \(result)]")
            throw Error.communicationFailure
        }
    }

    private func receivePacket() throws -> [UInt8] {
        guard isDeviceOpen else {
            Diag.warning("USB HID device must be opened")
            throw Error.communicationFailure
        }

        var buffer = [UInt8](repeating: 0, count: 8)
        var bufferLen = CFIndex(buffer.count)
        let result = IOHIDDeviceGetReport(
            hidDevice,
            kIOHIDReportTypeFeature,
            0,
            &buffer,
            &bufferLen
        )
        guard result == kIOReturnSuccess else {
            Diag.error("Failed to receive from USB HID device [code: \(result)]")
            throw Error.communicationFailure
        }
        return buffer
    }


    private func resetState() throws {
        var resetPacket = Data(repeating: 0, count: HIDLayer.featureReportSize)
        resetPacket[resetPacket.count - 1] = 0xFF
        try send(resetPacket)
    }

    private func awaitReadyToWrite() throws {
        for _ in 0..<20 {
            let statusByte = try receivePacket()[HIDLayer.featureReportDataSize]
            if statusByte & YubiKeyLayer.StatusFlags.slotWrite == 0 {
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
            if isCancelled {
                throw Error.cancelled
            }
        }
        Diag.info("Timeout waiting for YubiKey to become ready to receive")
        throw Error.responseTimeout
    }

    private func sendFrame(_ frame: Data) throws -> UInt8 {
        assert(frame.count == 70, "YubiKey HID frame must be 70 bytes long")
        let sequenceNumber = try receivePacket()[YubiKeyLayer.configSequenceOffset]

        var seq: UInt8 = 0
        var frameStart = 0
        let packetSize = HIDLayer.featureReportDataSize
        while frameStart < frame.count {
            var packet = Data(frame[frameStart..<(frameStart + packetSize)])
            let mustSend = (seq == 0) || (seq == 9) || !packet.allSatisfy({ $0 == 0 })
            if mustSend {
                packet.append(0x80 | seq)
                try awaitReadyToWrite()
                try send(packet)
            }
            frameStart += packetSize
            seq += 1
        }
        return sequenceNumber
    }

    private func readFrame(configSequence: UInt8, observer: YubiKeyStateObserver?) throws -> Data {
        var response = Data()
        var needsTouch = false
        var seq = 0
        while true {
            let packet = try receivePacket()
            let statusByte = packet[HIDLayer.featureReportDataSize]
            if (statusByte & YubiKeyLayer.StatusFlags.pending) != 0 { 
                let receivedSeq: UInt8 = statusByte & YubiKeyLayer.StatusFlags.sequenceMask
                if receivedSeq == seq {
                    response.append(contentsOf: packet[0..<HIDLayer.featureReportDataSize])
                    seq += 1
                } else if receivedSeq == 0 {
                    try resetState()
                    return response
                } else {
                    assertionFailure("Unexpected sequence number received")
                }
            } else if statusByte == 0 { 
                let nextConfigSeq = packet[YubiKeyLayer.configSequenceOffset]
                guard response.isEmpty else {
                    Diag.error("YubiKey response is empty")
                    throw Error.communicationFailure
                }
                let isConfigSuccessfullyChanged = nextConfigSeq == configSequence + 1
                let isNoValidConfigPresent =
                    configSequence > 0 &&
                    nextConfigSeq == 0 &&
                    packet[YubiKeyLayer.touchLowOffset] & YubiKeyLayer.configStatusMask == 0
                if isConfigSuccessfullyChanged || isNoValidConfigPresent {
                    return Data(packet[1..<packet.count - 1])
                } else if needsTouch {
                    Diag.info("Timed out waiting for touch")
                    throw Error.touchTimeout
                } else {
                    Diag.error("YubiKey slot is not configured")
                    throw Error.slotNotConfigured
                }
            } else { 
                let timeout: TimeInterval
                if statusByte & YubiKeyLayer.StatusFlags.timeoutWait != 0 {
                    observer?(.waitingForTouch)
                    needsTouch = true
                    timeout = 0.3
                } else {
                    observer?(.processing)
                    timeout = 0.05
                }
                Thread.sleep(forTimeInterval: timeout)
                if isCancelled {
                    try resetState()
                    throw Error.cancelled
                }
            }
        }
    }

    private func rawSendAndReceive(
        slot: UInt8,
        data: Data,
        observer: YubiKeyStateObserver?
    ) throws -> Data {
        let paddedData = data.withZeroPadding(toSize: YubiKeyLayer.slotDataSize)
        guard paddedData.count <= YubiKeyLayer.slotDataSize else {
            Diag.warning("YubiKey payload too large for HID frame")
            throw Error.communicationFailure
        }

        let crc = paddedData.getISO13239Checksum()
        var frame = paddedData
        frame.append(slot)
        frame.append(UInt8(crc & 0xFF))
        frame.append(UInt8(crc >> 8))
        frame.append(contentsOf: [0x00, 0x00, 0x00])

        let configSeq = try sendFrame(frame)
        let response = try readFrame(configSequence: configSeq, observer: observer)
        return response
    }

    private func sendAndReceive(
        slot: UInt8,
        data: Data,
        expectedCount: Int,
        observer: YubiKeyStateObserver? = nil
    ) throws -> Data {
        let rawResponse = try rawSendAndReceive(slot: slot, data: data, observer: observer)
        let responseWithCRC = rawResponse.prefix(expectedCount + 2)
        let payloadCRCResidue = responseWithCRC.getISO13239Checksum()
        guard payloadCRCResidue == YubiKeyLayer.crcValidResidue else {
            Diag.warning("USB HID response has invalid CRC")
            throw Error.communicationFailure
        }
        let response = rawResponse.prefix(expectedCount) 
        return response
    }


    public func readSerialNumber() throws -> Int {
        let bytes = try sendAndReceive(
            slot: ConfigSlot.deviceSerial.rawValue,
            data: Data(count: 2 * HIDLayer.featureReportSize),
            expectedCount: 4
        )
        let serialNumber: Int =
            Int(bytes[0]) << 24 |
            Int(bytes[1]) << 16 |
            Int(bytes[2]) << 8 |
            Int(bytes[3])
        return serialNumber
    }

    public func performChallengeResponse(
        slot: ConfigSlot,
        challenge: Data,
        observer: YubiKeyStateObserver? = nil
    ) throws -> Data {
        assert(slot == .chalHMAC1 || slot == .chalHMAC2)
        let paddedChallenge = challenge.withPKCS7Padding(toSize: YubiKeyLayer.hmacChallengeSize)

        assert(paddedChallenge.count == YubiKeyLayer.hmacChallengeSize)
        let response = try sendAndReceive(
            slot: slot.rawValue,
            data: paddedChallenge,
            expectedCount: YubiKeyLayer.hmacResponseSize,
            observer: observer
        )
        assert(response.count == YubiKeyLayer.hmacResponseSize)
        return response
    }

    public func cancel() {
        if isDeviceOpen {
            isCancelled = true
        }
    }
#endif
}

#if targetEnvironment(macCatalyst)
fileprivate extension Data {
    func getISO13239Checksum() -> UInt16 {
        var crc: UInt16 = 0xFFFF
        self.forEach { byte in
            crc ^= UInt16(byte)
            (0..<8).forEach { _ in
                let lastBit = crc & 1
                crc >>= 1
                if lastBit != 0 {
                    crc ^= 0x8408
                }
            }
        }
        return crc
    }

    func withPKCS7Padding(toSize: Int) -> Data {
        var paddedData = self
        let paddingLength = toSize - self.count
        let pkcs7padding: [UInt8] = Array(repeating: UInt8(paddingLength), count: paddingLength)
        paddedData.append(contentsOf: pkcs7padding)
        return paddedData
    }

    func withZeroPadding(toSize: Int) -> Data {
        var paddedData = self
        let zeroPadding: [UInt8] = Array(repeating: 0, count: toSize - self.count)
        paddedData.append(contentsOf: zeroPadding)
        return paddedData
    }
}
#endif

#if targetEnvironment(macCatalyst)
fileprivate extension IOHIDDevice {
    private func getIntProperty(key: String) -> Int? {
        return IOHIDDeviceGetProperty(self, key as CFString) as? Int
    }
    private func getStringProperty(key: String) -> String? {
        return IOHIDDeviceGetProperty(self, key as CFString) as? String
    }

    func getVendorID() -> Int {
        return getIntProperty(key: kIOHIDVendorIDKey) ?? -1
    }
    func getProductID() -> Int {
        return getIntProperty(key: kIOHIDProductIDKey) ?? -1
    }
    func getProductName() -> String {
        return getStringProperty(key: kIOHIDProductKey) ?? "?"
    }
    func getPrimaryUsagePair() -> (Int, Int) {
        let primaryUsagePage = getIntProperty(key: kIOHIDPrimaryUsagePageKey) ?? -1
        let primaryUsage = getIntProperty(key: kIOHIDPrimaryUsageKey) ?? -1
        return (primaryUsagePage, primaryUsage)
    }
}
#endif
