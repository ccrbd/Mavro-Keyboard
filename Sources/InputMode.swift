// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Mavro's typing modes.
///
/// - `.iavro`: behaves like iAvro, the original Avro for Mac. The English you
///   type stays inline (underlined) while Bangla suggestions appear in a plain
///   list; ↑/↓ choose, Space commits. Digits are typed into the word.
/// - `.preview`: the Bangla word itself is shown inline, with a numbered
///   suggestion list (Tab / 1-9 to choose) that includes the English word.
/// - `.raw`: Deterministic phonetic transliteration with NO dictionary,
///   autocorrect, or suggestions. Each word is committed exactly as parsed:
///   `sonar → সনার`, `sOnar → সোনার`, `mon → মন`, `moN → মণ`.
///
/// `.iavro` and `.preview` share riti's suggestion engine (whose ordering is a
/// port of iAvro's); they differ only in how the composition is presented and
/// driven. Raw values are persisted, so existing ones must not change.
enum InputMode: Int {
    case preview = 0
    case raw = 1
    case iavro = 2

    /// Menu and ⌘⇧M cycle order.
    static let displayOrder: [InputMode] = [.iavro, .preview, .raw]

    var ritiPhoneticSuggestion: Bool { self != .raw }

    /// iAvro never offered the typed English as a candidate.
    var includesEnglishCandidate: Bool { self == .preview }

    /// iAvro keeps the typed English inline; the others show the Bangla word.
    var showsTypedTextInline: Bool { self == .iavro }

    /// ↑/↓ move through the suggestion list instead of committing.
    var arrowsChooseCandidates: Bool { self == .iavro }

    /// Tab and 1-9 pick candidates (Preview) rather than being typed/committed.
    var keysPickCandidates: Bool { self == .preview }

    var menuTitle: String {
        switch self {
        case .iavro: return "iAvro style (English inline, Bangla suggestions)"
        case .preview: return "Preview (Bangla inline + numbered suggestions)"
        case .raw: return "Raw (as-typed, no suggestions)"
        }
    }

    var hudText: String {
        switch self {
        case .iavro: return "iAvro style"
        case .preview: return "Preview mode"
        case .raw: return "Raw mode"
        }
    }
}

/// Output encoding — Unicode (modern) or one of two ANSI/Bijoy layouts (legacy
/// fonts), the equivalent of Windows Avro's "ASCII" output. riti always emits
/// Unicode; the controller converts committed text to the chosen layout.
enum OutputEncoding: Int, CaseIterable {
    case unicode = 0
    case ansiSutonnyMJ = 1
    case ansiKalpurush = 2

    var menuTitle: String {
        switch self {
        case .unicode: return "Unicode (modern)"
        case .ansiSutonnyMJ: return "ANSI \u{2014} SutonnyMJ / classic Bijoy"
        case .ansiKalpurush: return "ANSI \u{2014} Kalpurush"
        }
    }

    var hudText: String {
        switch self {
        case .unicode: return "Unicode output"
        case .ansiSutonnyMJ: return "ANSI \u{00B7} SutonnyMJ"
        case .ansiKalpurush: return "ANSI \u{00B7} Kalpurush"
        }
    }
}

/// Centralizes reading/writing the active mode + encoding and broadcasting
/// changes so any live `MavroInputController` rebuilds its riti context.
enum ModeSettings {
    private static let modeKey = "MavroInputMode"
    private static let encodingKey = "MavroOutputEncoding"

    /// Posted whenever mode or encoding changes; controllers observe it to
    /// rebuild the engine with the new flags.
    static let didChange = Notification.Name("MavroSettingsDidChange")

    static var current: InputMode {
        get {
            // Fresh installs start in iAvro style — what Mac Avro users expect.
            guard UserDefaults.standard.object(forKey: modeKey) != nil else { return .iavro }
            return InputMode(rawValue: UserDefaults.standard.integer(forKey: modeKey)) ?? .iavro
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    static var encoding: OutputEncoding {
        get { OutputEncoding(rawValue: UserDefaults.standard.integer(forKey: encodingKey)) ?? .unicode }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: encodingKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Cycles iAvro style -> Preview -> Raw -> iAvro style.
    static func toggleMode() {
        let order = InputMode.displayOrder
        let next = ((order.firstIndex(of: current) ?? 0) + 1) % order.count
        current = order[next]
    }
    /// Cycles Unicode -> SutonnyMJ -> Kalpurush -> Unicode.
    static func toggleEncoding() {
        encoding = OutputEncoding(rawValue: (encoding.rawValue + 1) % OutputEncoding.allCases.count) ?? .unicode
    }
}
