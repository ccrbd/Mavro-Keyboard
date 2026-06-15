// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// Unicode <-> ANSI (Bijoy/SutonnyMJ) converter.
///
/// The two-pane UI is in place. The actual Bijoy mapping is being implemented
/// against a verified mapping table (Bijoy reorders pre-base vowel signs and
/// uses font-specific conjunct sequences, so a guessed table would silently
/// corrupt text). Until then the convert action surfaces that state instead of
/// emitting wrong output.
final class ConverterWindowController {
    static let shared = ConverterWindowController()
    private var window: NSWindow?
    private var unicodeView: NSTextView?
    private var ansiView: NSTextView?
    private var statusLabel: NSTextField?

    func show() {
        if window == nil { build() }
        if let window = window { ToolWindowCoordinator.shared.present(window) }
    }

    private func build() {
        let w: CGFloat = 640, h: CGFloat = 360
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        win.title = "Mavro \u{2014} Unicode \u{2194} ANSI Converter"
        win.isReleasedWhenClosed = false
        win.center()
        win.minSize = NSSize(width: 480, height: 280)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        root.autoresizingMask = [.width, .height]

        let pad: CGFloat = 16
        let buttonRowH: CGFloat = 40
        let statusH: CGFloat = 22
        let paneW = (w - pad * 3) / 2
        let paneY = pad + statusH + buttonRowH
        let paneH = h - paneY - pad - 22

        func makePane(_ title: String, x: CGFloat) -> NSTextView {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: x, y: paneY + paneH, width: paneW, height: 18)
            label.autoresizingMask = [.minYMargin]
            root.addSubview(label)

            let scroll = NSScrollView(frame: NSRect(x: x, y: paneY, width: paneW, height: paneH))
            scroll.hasVerticalScroller = true
            scroll.borderType = .bezelBorder
            scroll.autoresizingMask = [.width, .height]
            let tv = NSTextView(frame: scroll.bounds)
            tv.minSize = NSSize(width: 0, height: paneH)
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tv.isVerticallyResizable = true
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = [.width]
            tv.textContainer?.widthTracksTextView = true
            tv.font = .systemFont(ofSize: 16)
            // Plain text only (so pasted rich text doesn't carry a hard-coded
            // black color that's invisible in dark mode) + adaptive colors.
            tv.isRichText = false
            tv.usesFontPanel = false
            tv.allowsUndo = true
            tv.drawsBackground = true
            tv.backgroundColor = .textBackgroundColor
            tv.textColor = .textColor
            tv.insertionPointColor = .textColor
            scroll.documentView = tv
            root.addSubview(scroll)
            return tv
        }

        unicodeView = makePane("Unicode", x: pad)
        // poriborton emits the Kalpurush-ANSI codepoint layout, so preview the
        // output in that font to render it as real Bengali (not Latin gibberish).
        ansiView = makePane("ANSI (Bijoy) \u{00B7} Kalpurush ANSI preview", x: pad * 2 + paneW)
        applyAnsiPreviewFont()

        let toAnsi = NSButton(title: "Unicode \u{2192} ANSI", target: self, action: #selector(convertToAnsi))
        toAnsi.bezelStyle = .rounded
        toAnsi.frame = NSRect(x: pad, y: pad + statusH, width: 160, height: 30)
        toAnsi.autoresizingMask = [.maxXMargin]
        root.addSubview(toAnsi)

        let toUnicode = NSButton(title: "ANSI \u{2192} Unicode", target: self, action: #selector(convertToUnicode))
        toUnicode.bezelStyle = .rounded
        toUnicode.frame = NSRect(x: pad + 170, y: pad + statusH, width: 160, height: 30)
        toUnicode.autoresizingMask = [.maxXMargin]
        root.addSubview(toUnicode)

        let status = NSTextField(labelWithString: "Type or paste Unicode Bengali on the left, then Unicode \u{2192} ANSI.")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .tertiaryLabelColor
        status.frame = NSRect(x: pad, y: pad - 2, width: w - pad * 2, height: statusH)
        status.autoresizingMask = [.width]
        root.addSubview(status)
        statusLabel = status

        win.contentView = root
        window = win
    }

    @objc private func convertToAnsi() {
        let input = unicodeView?.string ?? ""
        guard !input.isEmpty else {
            statusLabel?.stringValue = "Enter Unicode Bengali text on the left first."
            return
        }
        var result = ""
        input.withCString { cstr in
            if let out = mavro_unicode_to_ansi(cstr) {
                result = String(cString: out)
                mavro_free_string(out)
            }
        }
        ansiView?.string = result
        applyAnsiPreviewFont()
        statusLabel?.stringValue = "Converted Unicode \u{2192} ANSI. Previewing in Kalpurush ANSI; copy the text to use elsewhere."
    }

    /// Render the ANSI pane in Kalpurush ANSI (poriborton's target layout) so the
    /// output reads as Bengali. Falls back to a mono font if it isn't installed.
    private func applyAnsiPreviewFont() {
        let font = NSFont(name: "Kalpurush ANSI", size: 20)
            ?? NSFont(name: "Kalpurush", size: 20)
            ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        ansiView?.font = font
    }

    @objc private func convertToUnicode() {
        // poriborton (and the wider Avro ecosystem) only ships a verified
        // forward map; a correct Bijoy -> Unicode reverse is non-trivial and is
        // not shipped rather than risk silently corrupting text.
        statusLabel?.stringValue = "ANSI \u{2192} Unicode isn't available yet (no verified reverse mapping)."
        NSSound.beep()
    }
}
