import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = CognitoAuthManager()

    var body: some View {
        Group {
            if authManager.isSignedIn {
                AppointmentListView()
                    .environmentObject(authManager)
            } else {
                CognitoAuthView()
                    .environmentObject(authManager)
            }
        }
        // Clamp the upper bound so text remains legible at large Dynamic Type
        // sizes without layouts breaking at the absolute maximum (AX5). The
        // app still scales fully up through accessibility3, which covers the
        // vast majority of users with visual impairments.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
