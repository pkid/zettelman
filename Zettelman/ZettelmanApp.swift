import SwiftUI

@main
struct ZettelmanApp: App {
    init() {
        AmplifyConfiguration.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
