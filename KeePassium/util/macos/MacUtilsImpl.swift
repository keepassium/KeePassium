//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AppKit
import Carbon

class MacUtilsImpl: NSObject, MacUtils {
    private enum Constants {
        static let accesibiliyURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        static let characterTypingDelay = 0.02
        static let tabDelay = 0.3
        static let tabKeyCode: CGKeyCode = 0x30
        static let autoTypeDelay = 1.5
    }

    required override init() {
    }

    func disableSecureEventInput() {
        DisableSecureEventInput()
    }

    func isSecureEventInputEnabled() -> Bool {
        return IsSecureEventInputEnabled()
    }

    func isControlKeyPressed() -> Bool {
        return (GetCurrentKeyModifiers() & UInt32(controlKey)) != 0
    }

    func isAccessibilityPermissionGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    func openAccessibilityPermissionSettings() {
        if let url = URL(string: Constants.accesibiliyURL) {
            NSWorkspace.shared.open(url)
        }
    }

    func requestAccessibilityPermission() {
        DispatchQueue.global(qos: .userInteractive).async {
            let source = CGEventSource(stateID: .combinedSessionState)
            if let dummyEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                dummyEvent.flags = .maskCommand
                dummyEvent.post(tap: .cghidEventTap)
            }

            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    func hideApplication() {
        NSApplication.shared.hide(nil)
    }

    func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func performAutoType(username: String, password: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.autoTypeDelay) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else {
                completion(false)
                return
            }
            self.performCGEventTyping(source: source, username: username, password: password, completion: completion)
        }
    }

    private func performCGEventTyping(
        source: CGEventSource,
        username: String,
        password: String,
        completion: @escaping (Bool) -> Void
    ) {
        let type = { (string: String) in
            for char in string {
                self.typeCharacter(char, source: source)
                Thread.sleep(forTimeInterval: Constants.characterTypingDelay)
            }
        }

        DispatchQueue.global(qos: .userInteractive).async {
            type(username)

            self.pressKey(keyCode: Constants.tabKeyCode, source: source)
            Thread.sleep(forTimeInterval: Constants.tabDelay)

            type(password)

            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    private func typeCharacter(_ char: Character, source: CGEventSource) {
        let utf16Chars = Array(char.utf16)
        let typeAndPost = { (event: CGEvent) in
            event.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
            event.post(tap: .cghidEventTap)
        }

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
            typeAndPost(keyDown)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
            typeAndPost(keyUp)
        }
    }

    private func pressKey(keyCode: CGKeyCode, source: CGEventSource) {
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
