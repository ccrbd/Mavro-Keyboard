// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa
import InputMethodKit

// MUST match Info.plist's InputMethodConnectionName.
let kConnectionName = "com.mavro.inputmethod.Mavro_Connection"

// IMKServer must outlive the process; keep it global.
var server: IMKServer!

NSLog("Mavro: starting input method service")

autoreleasepool {
    server = IMKServer(name: kConnectionName, bundleIdentifier: Bundle.main.bundleIdentifier!)

    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate

    withExtendedLifetime(delegate) {
        NSApplication.shared.run()
    }
}
