import SwiftUI

@main
struct messageAIApp: App {
    // Initialize Firebase when app launches
    init() {
        FirebaseConfig.shared.configure()
    }
    
    // Auth view model as state object
    @StateObject private var authViewModel = AuthViewModel()

    // Global app state for tracking current conversation
    @StateObject private var appState = AppStateService()
    
    // Track app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(appState)
                .task {
                    // Request notification permissions
                    await NotificationService.shared.requestPermission()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        Task {
            let realtimeDBService = RealtimeDBService.shared
            
            switch phase {
            case .active:
                print("📱 App became active")
                await realtimeDBService.setUserOnline(userId: userId)
                await SyncService.shared.processPendingMessages()
                
            case .inactive:
                print("📱 App became inactive")
                
            case .background:
                print("📱 App entered background")
                await realtimeDBService.setUserOffline(userId: userId)
                
            @unknown default:
                break
            }
        }
    }
}
