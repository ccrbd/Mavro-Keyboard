// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// Mouse-driven Bengali character map. Clicking a glyph types it into the
/// frontmost app (via a synthesized Unicode key event) and also copies it to
/// the clipboard as a guaranteed fallback.
final class CharacterMapWindowController {
    static let shared = CharacterMapWindowController()
    private var window: NSWindow?

    // Curated set of commonly needed Bengali characters, grouped. This is a
    // browse/click palette — not every codepoint, but the practical set.
    private let groups: [(String, [String])] = [
        ("Vowels", ["অ","আ","ই","ঈ","উ","ঊ","ঋ","এ","ঐ","ও","ঔ"]),
        ("Vowel signs (kar)", ["া","ি","ী","ু","ূ","ৃ","ে","ৈ","ো","ৌ","ঁ","ং","ঃ","্"]),
        ("Consonants", ["ক","খ","গ","ঘ","ঙ","চ","ছ","জ","ঝ","ঞ","ট","ঠ","ড","ঢ","ণ",
                         "ত","থ","দ","ধ","ন","প","ফ","ব","ভ","ম","য","র","ল","শ","ষ","স","হ"]),
        ("Extra", ["ড়","ঢ়","য়","ৎ","ৰ","ৱ"]),
        ("Digits", ["০","১","২","৩","৪","৫","৬","৭","৮","৯"]),
        ("Symbols", ["।","৳","ৎ","‍","‌"]),
    ]

    func show() {
        if window == nil { build() }
        if let window = window { ToolWindowCoordinator.shared.present(window) }
    }

    private func build() {
        let columns = 12
        let cell: CGFloat = 38
        let pad: CGFloat = 12
        let labelH: CGFloat = 22

        let contentW = CGFloat(columns) * cell + pad * 2

        // Pre-compute total height: each group has one label row plus N grid rows.
        var totalH = pad * 2
        for (_, chars) in groups {
            let rows = Int(ceil(Double(chars.count) / Double(columns)))
            totalH += labelH + CGFloat(rows) * cell
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentW, height: totalH),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "Mavro \u{2014} Character Map"
        win.isReleasedWhenClosed = false
        win.center()

        let root = NSView(frame: NSRect(x: 0, y: 0, width: contentW, height: totalH))

        // Lay out top-to-bottom. `top` is the y of the top edge of the next element.
        var top = totalH - pad
        for (name, chars) in groups {
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: pad, y: top - labelH, width: contentW - pad * 2, height: labelH)
            root.addSubview(label)
            top -= labelH

            for (i, ch) in chars.enumerated() {
                let col = i % columns
                let row = i / columns
                let x = pad + CGFloat(col) * cell
                let y = top - CGFloat(row + 1) * cell
                let btn = NSButton(frame: NSRect(x: x + 1, y: y + 1, width: cell - 2, height: cell - 2))
                btn.title = ch
                btn.font = .systemFont(ofSize: 18)
                btn.bezelStyle = .smallSquare
                btn.target = self
                btn.action = #selector(charClicked(_:))
                btn.identifier = NSUserInterfaceItemIdentifier(ch)
                root.addSubview(btn)
            }
            let rows = Int(ceil(Double(chars.count) / Double(columns)))
            top -= CGFloat(rows) * cell
        }

        win.contentView = root
        window = win
    }

    @objc private func charClicked(_ sender: NSButton) {
        guard let ch = sender.identifier?.rawValue else { return }
        // Clipboard fallback (always works).
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(ch, forType: .string)
        // Best-effort direct insertion into the frontmost app.
        TextInsertion.type(ch)
    }
}

/// Synthesizes a Unicode keystroke to insert text into whatever app is frontmost.
enum TextInsertion {
    static func type(_ string: String) {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        var utf16 = Array(string.utf16)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else { return }
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
