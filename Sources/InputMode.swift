// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Mavro's two typing modes — the core UX requirement.
///
/// - `.preview`: Avro-style. riti runs dictionary lookup + autocorrect and
///   shows a candidate window of suggestions while you type.
/// - `.raw`: Deterministic phonetic transliteration with NO dictionary,
///   autocorrect, or suggestions. Each word is committed exactly as parsed:
///   `sonar → সনার`, `sOnar → সোনার`, `mon → মন`, `moN → মণ`.
///
/// Maps onto riti's `phonetic_suggestion` flag (`.preview` → true, `.raw` → false).
enum InputMode: Int {
    case preview = 0
    case raw = 1

    var ritiPhoneticSuggestion: Bool { self == .preview }

    var menuTitle: String {
        switch self {
        case .preview: return "Preview (suggestions + autocorrect)"
        case .raw: return "Raw (as-typed, no autocorrect)"
        }
    }

    var hudText: String { self == .raw ? "Raw mode" : "Preview mode" }
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
        get { InputMode(rawValue: UserDefaults.standard.integer(forKey: modeKey)) ?? .preview }
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

    static func toggleMode() { current = (current == .raw) ? .preview : .raw }
    /// Cycles Unicode -> SutonnyMJ -> Kalpurush -> Unicode.
    static func toggleEncoding() {
        encoding = OutputEncoding(rawValue: (encoding.rawValue + 1) % OutputEncoding.allCases.count) ?? .unicode
    }
}
