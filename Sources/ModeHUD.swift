// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

/// A brief, centered on-screen flash (like a volume OSD) used to confirm a mode
/// switch. Necessary because the menu-bar item can be hidden behind the notch /
/// menu-bar overflow, so the menu checkmark isn't always visible.
final class ModeHUD {
    static let shared = ModeHUD()

    private var panel: NSPanel?
    private var label: NSTextField?
    private var hideWorkItem: DispatchWorkItem?

    func flash(_ text: String) {
        ensurePanel()
        guard let panel = panel, let label = label else { return }

        // Size the panel snugly to the text with symmetric padding so the label
        // sits centered (no empty gap below it).
        label.stringValue = text
        label.sizeToFit()
        let textSize = label.frame.size
        let padX: CGFloat = 30, padY: CGFloat = 18
        let w = max(150, textSize.width + padX * 2)
        let h = textSize.height + padY * 2
        panel.setContentSize(NSSize(width: w, height: h))
        label.frame = NSRect(x: (w - textSize.width) / 2,
                             y: (h - textSize.height) / 2,
                             width: textSize.width, height: textSize.height)

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - w / 2, y: f.midY - h / 2))
        }
        panel.alphaValue = 1
        panel.orderFront(nil)

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                self?.panel?.animator().alphaValue = 0
            } completionHandler: {
                self?.panel?.orderOut(nil)
            }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 160, height: 64),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        p.level = .popUpMenu
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let bg = NSVisualEffectView(frame: p.contentRect(forFrameRect: p.frame))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.masksToBounds = true
        bg.autoresizingMask = [.width, .height]

        let lbl = NSTextField(labelWithString: "")
        lbl.alignment = .center
        lbl.font = .systemFont(ofSize: 18, weight: .semibold)
        lbl.textColor = .labelColor
        lbl.autoresizingMask = [.width, .height]
        lbl.cell?.lineBreakMode = .byClipping
        bg.addSubview(lbl)

        p.contentView = bg
        self.panel = p
        self.label = lbl
    }
}
