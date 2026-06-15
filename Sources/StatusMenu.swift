// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// Menu-bar status item: the first-class place to switch typing mode and open
/// Mavro's tools. An improvement over hiding the mode behind a defaults key.
final class StatusMenu: NSObject {
    private var statusItem: NSStatusItem?

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Bengali letter "ম" as a lightweight, asset-free menu-bar label.
        item.button?.title = "\u{09AE}"
        item.button?.toolTip = "Mavro Keyboard"
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Mavro Keyboard", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let modeHeader = NSMenuItem(title: "Typing Mode  (toggle: \u{2318}\u{21E7}M)", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        for mode in [InputMode.preview, InputMode.raw] {
            let mi = NSMenuItem(title: mode.menuTitle, action: #selector(selectMode(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = mode.rawValue
            mi.state = (ModeSettings.current == mode) ? .on : .off
            menu.addItem(mi)
        }

        menu.addItem(.separator())

        let encHeader = NSMenuItem(title: "Output Encoding  (toggle: \u{2318}\u{21E7}E)", action: nil, keyEquivalent: "")
        encHeader.isEnabled = false
        menu.addItem(encHeader)

        for enc in OutputEncoding.allCases {
            let mi = NSMenuItem(title: enc.menuTitle, action: #selector(selectEncoding(_:)), keyEquivalent: "")
            mi.target = self
            mi.tag = enc.rawValue
            mi.state = (ModeSettings.encoding == enc) ? .on : .off
            menu.addItem(mi)
        }

        menu.addItem(.separator())

        let charMap = NSMenuItem(title: "Character Map\u{2026}", action: #selector(openCharacterMap), keyEquivalent: "")
        charMap.target = self
        menu.addItem(charMap)

        let converter = NSMenuItem(title: "Unicode \u{2194} ANSI Converter\u{2026}", action: #selector(openConverter), keyEquivalent: "")
        converter.target = self
        menu.addItem(converter)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Mavro", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        return menu
    }

    private func refreshChecks() {
        guard let menu = statusItem?.menu else { return }
        for item in menu.items {
            if item.action == #selector(selectMode(_:)) {
                item.state = (item.tag == ModeSettings.current.rawValue) ? .on : .off
            } else if item.action == #selector(selectEncoding(_:)) {
                item.state = (item.tag == ModeSettings.encoding.rawValue) ? .on : .off
            }
        }
    }

    // MARK: - Actions

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = InputMode(rawValue: sender.tag) else { return }
        ModeSettings.current = mode
        refreshChecks()
    }

    @objc private func selectEncoding(_ sender: NSMenuItem) {
        guard let enc = OutputEncoding(rawValue: sender.tag) else { return }
        ModeSettings.encoding = enc
        refreshChecks()
    }

    @objc private func openCharacterMap() {
        CharacterMapWindowController.shared.show()
    }

    @objc private func openConverter() {
        ConverterWindowController.shared.show()
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
