// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// Unicode <-> ANSI (Bijoy) converter with a selectable target layout:
///   - SutonnyMJ / classic Bijoy (ported verified bijoyconverter map; both ways)
///   - Kalpurush ANSI (poriborton; Unicode -> ANSI only)
/// The output pane previews in the matching font so it reads as Bengali.
final class ConverterWindowController {
    static let shared = ConverterWindowController()

    private enum Target: Int { case sutonnyMJ = 0, kalpurushANSI = 1 }

    private var window: NSWindow?
    private var unicodeView: NSTextView?
    private var ansiView: NSTextView?
    private var ansiLabel: NSTextField?
    private var statusLabel: NSTextField?
    private var target: Target = .sutonnyMJ

    func show() {
        if window == nil { build() }
        if let window = window { ToolWindowCoordinator.shared.present(window) }
    }

    // MARK: - Per-target details

    private var ansiFontName: String { target == .sutonnyMJ ? "SutonnyMJ" : "Kalpurush ANSI" }
    private var targetName: String { target == .sutonnyMJ ? "SutonnyMJ" : "Kalpurush ANSI" }

    private func build() {
        let w: CGFloat = 660, h: CGFloat = 380
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        win.title = "Mavro \u{2014} Unicode \u{2194} ANSI Converter"
        win.isReleasedWhenClosed = false
        win.center()
        win.minSize = NSSize(width: 520, height: 300)

        let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        root.autoresizingMask = [.width, .height]

        let pad: CGFloat = 16
        let buttonRowH: CGFloat = 40
        let statusH: CGFloat = 22
        let paneW = (w - pad * 3) / 2
        let paneY = pad + statusH + buttonRowH
        let paneH = h - paneY - pad - 22

        func makePane(_ title: String, x: CGFloat) -> (NSTextView, NSTextField) {
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
            // Plain text + adaptive colors (visible in dark mode; no pasted color).
            tv.isRichText = false
            tv.usesFontPanel = false
            tv.allowsUndo = true
            tv.drawsBackground = true
            tv.backgroundColor = .textBackgroundColor
            tv.textColor = .textColor
            tv.insertionPointColor = .textColor
            scroll.documentView = tv
            root.addSubview(scroll)
            return (tv, label)
        }

        let (uni, _) = makePane("Unicode", x: pad)
        unicodeView = uni
        let (ansi, ansiLbl) = makePane("ANSI (Bijoy)", x: pad * 2 + paneW)
        ansiView = ansi
        ansiLabel = ansiLbl

        let toAnsi = NSButton(title: "Unicode \u{2192} ANSI", target: self, action: #selector(convertToAnsi))
        toAnsi.bezelStyle = .rounded
        toAnsi.frame = NSRect(x: pad, y: pad + statusH, width: 150, height: 30)
        toAnsi.autoresizingMask = [.maxXMargin]
        root.addSubview(toAnsi)

        let toUnicode = NSButton(title: "ANSI \u{2192} Unicode", target: self, action: #selector(convertToUnicode))
        toUnicode.bezelStyle = .rounded
        toUnicode.frame = NSRect(x: pad + 158, y: pad + statusH, width: 150, height: 30)
        toUnicode.autoresizingMask = [.maxXMargin]
        root.addSubview(toUnicode)

        let picker = NSSegmentedControl(labels: ["SutonnyMJ", "Kalpurush ANSI"],
                                        trackingMode: .selectOne,
                                        target: self, action: #selector(targetChanged(_:)))
        picker.selectedSegment = target.rawValue
        let pickerW: CGFloat = 230
        picker.frame = NSRect(x: w - pad - pickerW, y: pad + statusH, width: pickerW, height: 28)
        picker.autoresizingMask = [.minXMargin]
        root.addSubview(picker)

        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: 11)
        status.textColor = .tertiaryLabelColor
        status.frame = NSRect(x: pad, y: pad - 2, width: w - pad * 2, height: statusH)
        status.autoresizingMask = [.width]
        root.addSubview(status)
        statusLabel = status

        win.contentView = root
        window = win

        applyTargetPresentation()
    }

    // MARK: - Actions

    @objc private func targetChanged(_ sender: NSSegmentedControl) {
        target = Target(rawValue: sender.selectedSegment) ?? .sutonnyMJ
        applyTargetPresentation()
    }

    /// Update the ANSI pane font + labels to match the selected target.
    private func applyTargetPresentation() {
        let font = NSFont(name: ansiFontName, size: 20)
            ?? NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        ansiView?.font = font
        ansiLabel?.stringValue = "ANSI \u{00B7} \(targetName) preview"
        statusLabel?.stringValue = target == .sutonnyMJ
            ? "SutonnyMJ / classic Bijoy \u{2014} converts both directions."
            : "Kalpurush ANSI \u{2014} Unicode \u{2192} ANSI only (no verified reverse)."
    }

    @objc private func convertToAnsi() {
        let input = unicodeView?.string ?? ""
        guard !input.isEmpty else {
            statusLabel?.stringValue = "Enter Unicode Bengali text on the left first."
            return
        }
        var result = ""
        input.withCString { cstr in
            let out = target == .sutonnyMJ ? mavro_unicode_to_bijoy(cstr) : mavro_unicode_to_ansi(cstr)
            if let out = out {
                result = String(cString: out)
                mavro_free_string(out)
            }
        }
        ansiView?.string = result
        applyTargetPresentation()
        statusLabel?.stringValue = "Converted Unicode \u{2192} \(targetName). Preview in \(ansiFontName); copy to use elsewhere."
    }

    @objc private func convertToUnicode() {
        guard target == .sutonnyMJ else {
            statusLabel?.stringValue = "ANSI \u{2192} Unicode is available for SutonnyMJ only \u{2014} switch the target."
            NSSound.beep()
            return
        }
        let input = ansiView?.string ?? ""
        guard !input.isEmpty else {
            statusLabel?.stringValue = "Enter SutonnyMJ/Bijoy text on the right first."
            return
        }
        var result = ""
        input.withCString { cstr in
            if let out = mavro_bijoy_to_unicode(cstr) {
                result = String(cString: out)
                mavro_free_string(out)
            }
        }
        unicodeView?.string = result
        statusLabel?.stringValue = "Converted SutonnyMJ \u{2192} Unicode."
    }
}
