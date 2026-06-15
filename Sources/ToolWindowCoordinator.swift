// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// Presents Mavro's tool windows (Character Map, Converter). While at least one
/// is open, the app is promoted to a regular app so it gets a **Dock icon** and
/// shows up in **⌘-Tab** — so you can switch back and forth (essential for the
/// converter) without hunting for the menu-bar item. When the last tool window
/// closes, it drops back to a background agent.
final class ToolWindowCoordinator: NSObject, NSWindowDelegate {
    static let shared = ToolWindowCoordinator()

    private var openWindows = Set<NSWindow>()

    func present(_ window: NSWindow) {
        window.delegate = self
        openWindows.insert(window)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        openWindows.remove(window)
        if openWindows.isEmpty {
            // No tool windows left: revert to a background input-method agent.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
