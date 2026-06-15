// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusMenu = StatusMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu.install()
    }
}
