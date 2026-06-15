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
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
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
            scroll.documentView = tv
            root.addSubview(scroll)
            return tv
        }

        unicodeView = makePane("Unicode", x: pad)
        ansiView = makePane("ANSI (Bijoy)", x: pad * 2 + paneW)

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

        let status = NSTextField(labelWithString: "Bijoy mapping is under construction \u{2014} conversion not yet active.")
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
        statusLabel?.stringValue = "Unicode \u{2192} ANSI conversion is not implemented yet."
        NSSound.beep()
    }

    @objc private func convertToUnicode() {
        statusLabel?.stringValue = "ANSI \u{2192} Unicode conversion is not implemented yet."
        NSSound.beep()
    }
}
