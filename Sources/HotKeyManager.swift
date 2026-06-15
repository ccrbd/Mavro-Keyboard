// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Carbon.HIToolbox
import Foundation

/// System-level hotkeys for switching mode (⌘M) and output encoding (⌘E).
///
/// These are registered ONLY while Mavro is the active input method (the
/// controller calls `acquire()` in activateServer and `release()` in
/// deactivateServer, ref-counted across clients). Carbon hotkeys intercept the
/// combo before the front app's menu, so ⌘M toggles the mode instead of
/// minimizing the window — but only while you're actually typing with Mavro.
/// When you switch back to another input source, the hotkeys are unregistered
/// and ⌘M / ⌘E behave normally again.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var activeClients = 0
    private var modeRef: EventHotKeyRef?
    private var encodingRef: EventHotKeyRef?
    private var handlerInstalled = false

    private let signature: OSType = 0x4D41_564F // 'MAVO'
    private let modeHotKeyID: UInt32 = 1
    private let encodingHotKeyID: UInt32 = 2

    /// Called when a client becomes active. Registers on the first one.
    func acquire() {
        activeClients += 1
        if activeClients == 1 { register() }
    }

    /// Called when a client deactivates. Unregisters when none remain active.
    func release() {
        activeClients = max(0, activeClients - 1)
        if activeClients == 0 { unregister() }
    }

    // MARK: - Registration

    private func register() {
        installHandlerIfNeeded()
        let target = GetEventDispatcherTarget()

        // Command-Shift modifiers: safe combos that don't clobber common
        // Command shortcuts (e.g. ⌘E center-text in Word) even while active.
        let mods = UInt32(cmdKey | shiftKey)

        var ref: EventHotKeyRef?
        let modeID = EventHotKeyID(signature: signature, id: modeHotKeyID)
        if RegisterEventHotKey(UInt32(kVK_ANSI_M), mods, modeID, target, 0, &ref) == noErr {
            modeRef = ref
        }

        ref = nil
        let encID = EventHotKeyID(signature: signature, id: encodingHotKeyID)
        if RegisterEventHotKey(UInt32(kVK_ANSI_E), mods, encID, target, 0, &ref) == noErr {
            encodingRef = ref
        }
    }

    private func unregister() {
        if let r = modeRef { UnregisterEventHotKey(r); modeRef = nil }
        if let r = encodingRef { UnregisterEventHotKey(r); encodingRef = nil }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        // Non-capturing C callback: routes to the singleton on the main thread.
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let id = hkID.id
            DispatchQueue.main.async { HotKeyManager.shared.fire(id) }
            return noErr
        }, 1, &spec, nil, nil)
    }

    // MARK: - Dispatch

    private func fire(_ id: UInt32) {
        switch id {
        case modeHotKeyID:
            ModeSettings.toggleMode()
            ModeHUD.shared.flash(ModeSettings.current.hudText)
        case encodingHotKeyID:
            ModeSettings.toggleEncoding()
            ModeHUD.shared.flash(ModeSettings.encoding.hudText)
        default:
            break
        }
    }
}
