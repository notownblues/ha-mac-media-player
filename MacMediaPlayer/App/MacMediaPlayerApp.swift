import SwiftUI

@main
struct MacMediaPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesWindow()
        }
    }
}
