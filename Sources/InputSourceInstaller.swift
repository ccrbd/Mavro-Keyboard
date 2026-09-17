// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Carbon
import Foundation

/// `Mavro --install` (run by the installer): register this bundle with the Text
/// Input Sources system and enable it, so Mavro shows up in the input menu
/// straight away instead of after a logout plus a trip to System Settings.
/// Best-effort — the installer still explains the manual steps if it fails.
enum InputSourceInstaller {
    static func registerAndEnable() -> Int32 {
        let bundle = Bundle.main
        guard let bundleID = bundle.bundleIdentifier else { return 1 }

        let registerStatus = TISRegisterInputSource(bundle.bundleURL as CFURL)

        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        let sources = (TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]) ?? []
        let keyboardSources = sources.filter {
            property($0, kTISPropertyInputSourceCategory) as String? == (kTISCategoryKeyboardInputSource as String)
        }
        guard !keyboardSources.isEmpty else {
            print("Mavro: registration status \(registerStatus); not listed yet (log out and back in).")
            return 1
        }

        var allEnabled = true
        for source in keyboardSources {
            if property(source, kTISPropertyInputSourceIsEnabled) as Bool? == true { continue }
            let status = TISEnableInputSource(source)
            if status != noErr {
                allEnabled = false
                print("Mavro: could not enable input source (status \(status)).")
            }
        }
        print(allEnabled ? "Mavro: input source registered and enabled." : "Mavro: registered, but enabling failed.")
        return allEnabled ? 0 : 1
    }

    private static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
    }
}
