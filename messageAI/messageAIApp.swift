import SwiftUI

@main
struct messageAIApp: App {
    // Initialize Firebase when app launches
    init() {
        _ = FirebaseConfig.shared
        _ = NetworkMonitor.shared
        _ = SyncService.shared
    }
    
    // Auth view model as state object
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
