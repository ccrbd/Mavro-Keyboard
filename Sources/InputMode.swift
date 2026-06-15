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
/// The distinction maps directly onto riti's `phonetic_suggestion` config flag:
/// `.preview` sets it `true`, `.raw` sets it `false` (riti then returns a single
/// "lonely" transliteration that we commit inline).
enum InputMode: Int {
    case preview = 0
    case raw = 1

    /// Value to pass to `riti_config_set_phonetic_suggestion`.
    var ritiPhoneticSuggestion: Bool {
        switch self {
        case .preview: return true
        case .raw: return false
        }
    }

    var menuTitle: String {
        switch self {
        case .preview: return "Preview (suggestions + autocorrect)"
        case .raw: return "Raw (as-typed, no autocorrect)"
        }
    }
}

/// Centralizes reading/writing the active mode and broadcasting changes so any
/// live `MavroInputController` instance rebuilds its riti context.
enum ModeSettings {
    static let defaultsKey = "MavroInputMode"

    /// Posted whenever the active mode changes. Controllers observe this to
    /// rebuild the engine with the new `phonetic_suggestion` setting.
    static let didChange = Notification.Name("MavroInputModeDidChange")

    static var current: InputMode {
        get {
            // Defaults to Preview (the familiar Avro behavior) on first run.
            InputMode(rawValue: UserDefaults.standard.integer(forKey: defaultsKey)) ?? .preview
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }
}
