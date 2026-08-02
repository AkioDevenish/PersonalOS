import SwiftUI

@main
struct PersonalOSHealthApp: App {
    @StateObject private var health = HealthKitManager()
    @AppStorage("onboarded") private var onboarded = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    RootView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(health)
        }
    }
}
