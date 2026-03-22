import Amplify
import AWSCognitoAuthPlugin
import AWSS3StoragePlugin
import Foundation

enum AmplifyConfiguration {
    private static var isConfigured = false

    static func configure() {
        guard !isConfigured else { return }

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSS3StoragePlugin())
            try Amplify.configure()
            isConfigured = true
            print("Amplify configured successfully")
        } catch {
            print("Amplify configuration failed: \(error)")
        }
    }
}
