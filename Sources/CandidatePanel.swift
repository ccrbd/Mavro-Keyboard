// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Custom candidate window (a borderless NSPanel) rather than IMKCandidates,
// which is unreliable on recent macOS. Adapted from Lekho (MPL-2.0).

import Cocoa

class CandidatePanel {
    private var panel: NSPanel?
    private var contentView: CandidateView?

    /// Called when the user clicks a candidate. Parameter is the candidate index.
    var onCandidateSelected: ((Int) -> Void)?

    func show(candidates: [String], auxiliaryText: String, selectedIndex: Int, cursorRect: NSRect) {
        if panel == nil { createPanel() }
        guard let panel = panel, let contentView = contentView else { return }

        contentView.update(candidates: candidates, auxiliaryText: auxiliaryText, selectedIndex: selectedIndex)

        let size = contentView.idealSize()
        panel.setContentSize(size)

        // Position below the cursor (macOS coords: y increases upward).
        var origin = cursorRect.origin
        origin.y -= size.height + 4

        let cursorPoint = NSPoint(x: cursorRect.midX, y: cursorRect.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPoint) }) ?? NSScreen.main
        if let screen = screen {
            let sf = screen.visibleFrame
            origin.x = max(sf.minX, min(origin.x, sf.maxX - size.width))
            if origin.y < sf.minY { origin.y = cursorRect.maxY + 4 }            // flip above
            if origin.y + size.height > sf.maxY { origin.y = sf.maxY - size.height }
            if origin.y < sf.minY { origin.y = sf.minY }
        }

        panel.setFrameOrigin(origin)
        panel.orderFront(nil)
    }

    func hide() { panel?.orderOut(nil) }

    func selectCandidate(at index: Int) { contentView?.setSelectedIndex(index) }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = CandidateView()
        contentView.onCandidateClicked = { [weak self] index in self?.onCandidateSelected?(index) }
        panel.contentView = contentView

        self.panel = panel
        self.contentView = contentView
    }
}

// MARK: - CandidateView

class CandidateView: NSView {
    private var candidates: [String] = []
    private var auxiliaryText: String = ""
    private var selectedIndex: Int = 0
    private var scrollOffset: Int = 0

    /// Called when the user clicks a candidate row. Parameter is the index.
    var onCandidateClicked: ((Int) -> Void)?

    private let padding: CGFloat = 6
    private let rowHeight: CGFloat = 24
    private let auxHeight: CGFloat = 20
    private let maxVisibleCandidates = 9

    func update(candidates: [String], auxiliaryText: String, selectedIndex: Int) {
        self.candidates = candidates
        self.auxiliaryText = auxiliaryText
        self.selectedIndex = candidates.isEmpty ? 0 : min(selectedIndex, candidates.count - 1)
        adjustScroll()
        needsDisplay = true
    }

    func setSelectedIndex(_ index: Int) {
        self.selectedIndex = candidates.isEmpty ? 0 : min(index, candidates.count - 1)
        adjustScroll()
        needsDisplay = true
    }

    private func adjustScroll() {
        if selectedIndex < scrollOffset {
            scrollOffset = selectedIndex
        } else if selectedIndex >= scrollOffset + maxVisibleCandidates {
            scrollOffset = selectedIndex - maxVisibleCandidates + 1
        }
        scrollOffset = max(0, scrollOffset)
    }

    func idealSize() -> NSSize {
        let visibleCount = min(candidates.count - scrollOffset, maxVisibleCandidates)
        let height = CGFloat(visibleCount) * rowHeight + auxHeight + padding * 2
        return NSSize(width: 280, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds

        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor.windowBackgroundColor.setFill()
        bgPath.fill()
        NSColor.separatorColor.setStroke()
        bgPath.lineWidth = 0.5
        bgPath.stroke()

        let visibleStart = scrollOffset
        let visibleEnd = min(scrollOffset + maxVisibleCandidates, candidates.count)
        let visibleCount = visibleEnd - visibleStart

        if !auxiliaryText.isEmpty {
            let auxRect = NSRect(x: padding + 4, y: bounds.height - auxHeight - padding,
                                 width: bounds.width - padding * 2 - 8, height: auxHeight)
            let auxAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            auxiliaryText.draw(in: auxRect, withAttributes: auxAttrs)
        }

        let hasMoreAbove = scrollOffset > 0
        let hasMoreBelow = visibleEnd < candidates.count

        for i in 0..<visibleCount {
            let candidateIndex = scrollOffset + i
            let y = bounds.height - auxHeight - padding - CGFloat(i + 1) * rowHeight
            let rowRect = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: rowHeight)
            let isSelected = candidateIndex == selectedIndex

            if isSelected {
                let hp = NSBezierPath(roundedRect: rowRect, xRadius: 4, yRadius: 4)
                NSColor.selectedContentBackgroundColor.setFill()
                hp.fill()
            }

            let numRect = NSRect(x: padding + 4, y: y + 2, width: 22, height: rowHeight - 4)
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isSelected ? NSColor.alternateSelectedControlTextColor
                                             : NSColor.tertiaryLabelColor,
            ]
            "\(candidateIndex + 1)".draw(in: numRect, withAttributes: numAttrs)

            let textRect = NSRect(x: padding + 28, y: y + 2,
                                  width: bounds.width - padding * 2 - 32, height: rowHeight - 4)
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: isSelected ? NSColor.alternateSelectedControlTextColor
                                             : NSColor.labelColor,
            ]
            candidates[candidateIndex].draw(in: textRect, withAttributes: textAttrs)
        }

        let indicatorColor = NSColor.tertiaryLabelColor
        if hasMoreAbove {
            let arrowY = bounds.height - auxHeight - padding - 2
            drawTriangle(in: NSRect(x: bounds.width - 20, y: arrowY - 8, width: 12, height: 8),
                         up: true, color: indicatorColor)
        }
        if hasMoreBelow {
            let arrowY = bounds.height - auxHeight - padding - CGFloat(visibleCount) * rowHeight + 2
            drawTriangle(in: NSRect(x: bounds.width - 20, y: arrowY, width: 12, height: 8),
                         up: false, color: indicatorColor)
        }
    }

    private func drawTriangle(in rect: NSRect, up: Bool, color: NSColor) {
        let path = NSBezierPath()
        if up {
            path.move(to: NSPoint(x: rect.midX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: NSPoint(x: rect.midX, y: rect.minY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        }
        path.close()
        color.setFill()
        path.fill()
    }

    // MARK: - Mouse handling

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = candidateIndex(at: point) {
            selectedIndex = index
            adjustScroll()
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = candidateIndex(at: point), index == selectedIndex {
            onCandidateClicked?(index)
        }
    }

    private func candidateIndex(at point: NSPoint) -> Int? {
        let topOfCandidates = bounds.height - auxHeight - padding
        let clickOffset = topOfCandidates - point.y
        guard clickOffset >= 0 else { return nil }
        let rowIndex = Int(clickOffset / rowHeight)
        let candidateIndex = scrollOffset + rowIndex
        guard candidateIndex >= 0 && candidateIndex < candidates.count else { return nil }
        return candidateIndex
    }
}
