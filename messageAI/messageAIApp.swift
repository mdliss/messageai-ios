import SwiftUI

@main
struct messageAIApp: App {
    // Initialize Firebase when app launches
    init() {
        FirebaseConfig.shared.configure()
    }
    
    // Auth view model as state object
    @StateObject private var authViewModel = AuthViewModel()
    
    // Track app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .task {
                    // Request notification permissions
                    await NotificationService.shared.requestPermission()
                    await NotificationService.shared.getFCMToken()
                    
                    // Clear ALL unsynced messages from previous test sessions
                    CoreDataService.shared.clearAllUnsyncedMessages()
                    
                    // Update sync service pending count
                    SyncService.shared.updatePendingCount()
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
