// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// The key-handling pipeline and riti edge-case handling (lonely-suggestion
// guards, cursor-rect fallbacks) are adapted from Lekho (MPL-2.0) by ARahim3,
// which pioneered driving the riti engine from macOS InputMethodKit.

import Cocoa
import InputMethodKit

@objc(MavroInputController)
class MavroInputController: IMKInputController {

    // MARK: - Engine state

    private var engineCtx: OpaquePointer?
    private var engineConfig: OpaquePointer?
    private var currentSuggestion: OpaquePointer?
    private var selectedIndex: UInt = 0
    private var candidatePanel: CandidatePanel?
    private var lastKnownCursorRect: NSRect = .zero

    /// Bengali digits ০-৯ indexed by 0-9.
    private static let bengaliDigits: [Character] = [
        "\u{09E6}", "\u{09E7}", "\u{09E8}", "\u{09E9}", "\u{09EA}",
        "\u{09EB}", "\u{09EC}", "\u{09ED}", "\u{09EE}", "\u{09EF}",
    ]

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        initializeEngine()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(modeChanged),
            name: ModeSettings.didChange,
            object: nil
        )
    }

    private func initializeEngine() {
        engineConfig = riti_config_new()

        // Avro Phonetic layout.
        "avro_phonetic".withCString { _ = riti_config_set_layout_file(engineConfig, $0) }

        // Dictionary/autocorrect data bundled in Resources/data.
        let dataDir = Bundle.main.resourcePath! + "/data"
        dataDir.withCString { _ = riti_config_set_database_dir(engineConfig, $0) }

        // Writable per-user dir (learned selections, user autocorrect).
        let userDir = userDataDir()
        userDir.withCString { _ = riti_config_set_user_dir(engineConfig, $0) }

        // The mode → engine mapping. In Raw mode phonetic_suggestion is OFF, so
        // riti returns a single "lonely" transliteration committed inline with
        // no candidate window.
        riti_config_set_phonetic_suggestion(engineConfig, ModeSettings.current.ritiPhoneticSuggestion)
        riti_config_set_suggestion_include_english(engineConfig, true)

        engineCtx = riti_context_new_with_config(engineConfig)
    }

    /// Rebuild the riti context+config after a mode change. Any in-flight session
    /// is dropped (host marked text clears on the next keystroke).
    private func rebuildEngine() {
        if let ctx = engineCtx, riti_context_ongoing_input_session(ctx) {
            riti_context_finish_input_session(ctx)
        }
        freeSuggestion()
        hideCandidates()
        selectedIndex = 0

        if let ctx = engineCtx { riti_context_free(ctx); engineCtx = nil }
        if let cfg = engineConfig { riti_config_free(cfg); engineConfig = nil }
        initializeEngine()
    }

    @objc private func modeChanged() { rebuildEngine() }

    /// True when there's an ongoing session AND the suggestion is riti's "lonely"
    /// (Single) variant. In Raw mode every keystroke produces this. Used to bypass
    /// candidate-navigation handlers (Tab/arrows/1-9) that would otherwise call
    /// `get_length` on a Single variant and panic.
    private func inLonelySession() -> Bool {
        guard riti_context_ongoing_input_session(engineCtx),
              let suggestion = currentSuggestion,
              !riti_suggestion_is_empty(suggestion) else {
            return false
        }
        return riti_suggestion_is_lonely(suggestion)
    }

    private func userDataDir() -> String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("Mavro")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        freeSuggestion()
        if let ctx = engineCtx { riti_context_free(ctx) }
        if let config = engineConfig { riti_config_free(config) }
    }

    // MARK: - Key handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event,
              event.type == .keyDown,
              let client = sender as? (any IMKTextInput) else {
            return false
        }

        let modifiers = event.modifierFlags

        // Pass through Cmd/Ctrl shortcuts; commit any ongoing input first.
        if modifiers.contains(.command) || modifiers.contains(.control) {
            if riti_context_ongoing_input_session(engineCtx) {
                commitTopCandidate(client: client)
            }
            return false
        }

        let keyCode = event.keyCode

        // Return / numpad Enter — commit current selection.
        if keyCode == 36 || keyCode == 76 {
            if riti_context_ongoing_input_session(engineCtx) {
                commitTopCandidate(client: client)
                return true
            }
            return false
        }

        // Escape — cancel and clear.
        if keyCode == 53 {
            if riti_context_ongoing_input_session(engineCtx) {
                riti_context_finish_input_session(engineCtx)
                freeSuggestion()
                clearMarkedText(client)
                hideCandidates()
                return true
            }
            return false
        }

        // Backspace.
        if keyCode == 51 {
            if riti_context_ongoing_input_session(engineCtx) {
                let ctrlPressed = modifiers.contains(.control)
                freeSuggestion()
                currentSuggestion = riti_context_backspace_event(engineCtx, ctrlPressed)
                if riti_context_ongoing_input_session(engineCtx) {
                    updateMarkedText(client: client)
                    showCandidates(client: client)
                } else {
                    clearMarkedText(client)
                    hideCandidates()
                }
                return true
            }
            return false
        }

        // Space — commit first candidate, let the space pass through.
        if keyCode == 49 {
            if riti_context_ongoing_input_session(engineCtx) {
                commitTopCandidate(client: client)
                return false
            }
            return false
        }

        // Tab — navigate candidates (Shift+Tab backward).
        if keyCode == 48 {
            if riti_context_ongoing_input_session(engineCtx) {
                if inLonelySession() {
                    commitTopCandidate(client: client)
                    return false
                }
                navigateCandidates(forward: !modifiers.contains(.shift), client: client)
                return true
            }
            return false
        }

        // Bare digit (no session): insert Bengali numeral directly.
        if !riti_context_ongoing_input_session(engineCtx),
           let chars = event.characters, let digit = chars.first,
           digit >= "0" && digit <= "9" {
            insertBengaliDigit(digit, client: client)
            return true
        }

        // Digit 1-9 during a session: pick that candidate.
        if riti_context_ongoing_input_session(engineCtx),
           let chars = event.characters, let digit = chars.first,
           digit >= "1" && digit <= "9" {
            if inLonelySession() {
                commitTopCandidate(client: client)
                insertBengaliDigit(digit, client: client)
                return true
            }
            let index = Int(String(digit))! - 1
            let length = currentSuggestion != nil ? riti_suggestion_get_length(currentSuggestion) : 0
            if index < length {
                commitCandidate(at: index, client: client)
                return true
            }
        }

        // Down / Up arrows — navigate candidates.
        if keyCode == 125 || keyCode == 126 {
            if riti_context_ongoing_input_session(engineCtx) {
                if inLonelySession() {
                    commitTopCandidate(client: client)
                    return false
                }
                navigateCandidates(forward: keyCode == 125, client: client)
                return true
            }
            return false
        }

        // Printable characters → riti.
        guard let characters = event.characters,
              let firstChar = characters.unicodeScalars.first else {
            return false
        }

        let ritiKey = mavro_keycode_for_char(firstChar.value)
        if ritiKey == 0 {
            if riti_context_ongoing_input_session(engineCtx) {
                commitTopCandidate(client: client)
            }
            return false
        }

        let ritiModifier: UInt8 = modifiers.contains(.shift) ? UInt8(MODIFIER_SHIFT) : 0

        freeSuggestion()
        currentSuggestion = riti_get_suggestion_for_key(engineCtx, ritiKey, ritiModifier, UInt8(selectedIndex))

        if riti_context_ongoing_input_session(engineCtx) {
            updateMarkedText(client: client)
            showCandidates(client: client)
        } else {
            // Lonely suggestion (single char/punctuation, or Raw mode output).
            if let suggestion = currentSuggestion, !riti_suggestion_is_empty(suggestion) {
                if riti_suggestion_is_lonely(suggestion) {
                    if let textPtr = riti_suggestion_get_lonely_suggestion(suggestion) {
                        client.insertText(String(cString: textPtr) as NSString,
                                          replacementRange: notFoundRange)
                        riti_string_free(textPtr)
                    }
                } else {
                    commitTopCandidate(client: client)
                }
            }
            hideCandidates()
        }
        return true
    }

    // MARK: - Candidate navigation helpers

    private func navigateCandidates(forward: Bool, client: any IMKTextInput) {
        let length = currentSuggestion != nil ? riti_suggestion_get_length(currentSuggestion) : 0
        guard length > 0 else { return }
        if forward {
            selectedIndex = (selectedIndex + 1) % UInt(length)
        } else {
            selectedIndex = selectedIndex == 0 ? UInt(length - 1) : selectedIndex - 1
        }
        updateMarkedText(client: client)
        candidatePanel?.selectCandidate(at: Int(selectedIndex))
    }

    private func insertBengaliDigit(_ digit: Character, client: any IMKTextInput) {
        let value = Int(String(digit))!
        client.insertText(String(Self.bengaliDigits[value]) as NSString, replacementRange: notFoundRange)
    }

    // MARK: - Text management

    private var notFoundRange: NSRange { NSRange(location: NSNotFound, length: NSNotFound) }

    private func clearMarkedText(_ client: any IMKTextInput) {
        client.setMarkedText("" as NSString,
                             selectionRange: NSRange(location: 0, length: 0),
                             replacementRange: notFoundRange)
    }

    private func updateMarkedText(client: any IMKTextInput) {
        guard let suggestion = currentSuggestion, !riti_suggestion_is_empty(suggestion) else { return }

        // riti's len() panics on the Single (lonely) variant — never call it here.
        // get_pre_edit_text(0) works for both variants.
        let preEditIndex: UInt
        if riti_suggestion_is_lonely(suggestion) {
            preEditIndex = 0
        } else {
            let length = riti_suggestion_get_length(suggestion)
            if length == 0 { return }
            preEditIndex = min(selectedIndex, length - 1)
        }
        guard let preEditPtr = riti_suggestion_get_pre_edit_text(suggestion, preEditIndex) else { return }
        let preEditText = String(cString: preEditPtr)
        riti_string_free(preEditPtr)

        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
        ]
        client.setMarkedText(
            NSAttributedString(string: preEditText, attributes: attrs),
            selectionRange: NSRange(location: preEditText.utf16.count, length: 0),
            replacementRange: notFoundRange
        )
    }

    private func commitTopCandidate(client: any IMKTextInput) {
        commitCandidate(at: Int(selectedIndex), client: client)
    }

    private func commitCandidate(at index: Int, client: any IMKTextInput) {
        guard let suggestion = currentSuggestion, !riti_suggestion_is_empty(suggestion) else {
            riti_context_finish_input_session(engineCtx)
            freeSuggestion()
            hideCandidates()
            return
        }

        let text: String
        if riti_suggestion_is_lonely(suggestion) {
            let ptr = riti_suggestion_get_lonely_suggestion(suggestion)
            text = ptr != nil ? String(cString: ptr!) : ""
            if let ptr = ptr { riti_string_free(ptr) }
            // In Raw mode the buffer is filled every keystroke; must end the
            // session explicitly so the next key starts fresh.
            riti_context_finish_input_session(engineCtx)
        } else {
            let length = riti_suggestion_get_length(suggestion)
            let safeIndex = UInt(min(index, Int(length) - 1))
            let ptr = riti_suggestion_get_suggestion(suggestion, safeIndex)
            text = ptr != nil ? String(cString: ptr!) : ""
            if let ptr = ptr { riti_string_free(ptr) }
            riti_context_candidate_committed(engineCtx, safeIndex)
        }

        client.insertText(text as NSString, replacementRange: notFoundRange)
        selectedIndex = 0
        freeSuggestion()
        hideCandidates()
    }

    // MARK: - Cursor position for candidate window

    /// Resolve the on-screen cursor rect, with layered fallbacks for apps
    /// (Chrome/Electron) that return garbage. Call AFTER updateMarkedText.
    private func getCursorRect(client: any IMKTextInput) -> NSRect {
        let marked = client.markedRange()
        if marked.location != NSNotFound {
            let endRange = NSRange(location: marked.location + marked.length, length: 0)
            let rect = client.firstRect(forCharacterRange: endRange, actualRange: nil)
            if isValidCursorRect(rect) { lastKnownCursorRect = rect; return rect }
            let rect2 = client.firstRect(forCharacterRange: marked, actualRange: nil)
            if isValidCursorRect(rect2) { lastKnownCursorRect = rect2; return rect2 }
        }
        let sel = client.selectedRange()
        if sel.location != NSNotFound {
            let rect = client.firstRect(forCharacterRange: sel, actualRange: nil)
            if isValidCursorRect(rect) { lastKnownCursorRect = rect; return rect }
        }
        for idx in [marked.location, sel.location, 0] {
            guard idx != NSNotFound else { continue }
            var lineRect = NSRect.zero
            client.attributes(forCharacterIndex: idx, lineHeightRectangle: &lineRect)
            if isValidCursorRect(lineRect) { lastKnownCursorRect = lineRect; return lineRect }
        }
        if lastKnownCursorRect.size.height >= 1 { return lastKnownCursorRect }
        let m = NSEvent.mouseLocation
        let fallback = NSRect(x: m.x, y: m.y - 20, width: 0, height: 20)
        lastKnownCursorRect = fallback
        return fallback
    }

    private func isValidCursorRect(_ rect: NSRect) -> Bool {
        if rect.origin.x.isSubnormal || rect.origin.y.isSubnormal ||
            rect.size.width.isSubnormal || rect.size.height.isSubnormal { return false }
        if rect.origin.x < 1 && rect.origin.y < 1 { return false }
        if rect.size.height < 1 { return false }
        return NSScreen.screens.contains { $0.frame.contains(rect.origin) }
    }

    // MARK: - Candidate window

    private func showCandidates(client: any IMKTextInput) {
        guard let suggestion = currentSuggestion,
              !riti_suggestion_is_empty(suggestion),
              !riti_suggestion_is_lonely(suggestion) else {
            hideCandidates()
            return
        }

        let length = riti_suggestion_get_length(suggestion)
        var candidates: [String] = []
        for i in 0..<length {
            if let ptr = riti_suggestion_get_suggestion(suggestion, i) {
                candidates.append(String(cString: ptr))
                riti_string_free(ptr)
            }
        }

        let auxPtr = riti_suggestion_get_auxiliary_text(suggestion)
        let auxText = auxPtr != nil ? String(cString: auxPtr!) : ""
        if let auxPtr = auxPtr { riti_string_free(auxPtr) }

        let cursorRect = getCursorRect(client: client)

        if candidatePanel == nil {
            candidatePanel = CandidatePanel()
            candidatePanel?.onCandidateSelected = { [weak self] index in
                guard let self = self,
                      let client = self.client() as (any IMKTextInput)? else { return }
                self.commitCandidate(at: index, client: client)
            }
        }

        let prevIndex = riti_suggestion_previously_selected_index(suggestion)
        selectedIndex = (prevIndex >= 0 && UInt(prevIndex) < length) ? UInt(prevIndex) : 0

        candidatePanel?.show(
            candidates: candidates,
            auxiliaryText: auxText,
            selectedIndex: Int(selectedIndex),
            cursorRect: cursorRect
        )
    }

    private func hideCandidates() { candidatePanel?.hide() }

    private func freeSuggestion() {
        if let suggestion = currentSuggestion {
            riti_suggestion_free(suggestion)
            currentSuggestion = nil
        }
    }

    // MARK: - Session lifecycle

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        selectedIndex = 0
        freeSuggestion()
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = sender as? (any IMKTextInput), riti_context_ongoing_input_session(engineCtx) {
            commitTopCandidate(client: client)
        }
        freeSuggestion()
        hideCandidates()
        super.deactivateServer(sender)
    }
}
