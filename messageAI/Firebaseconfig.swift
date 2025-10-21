import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseDatabase

final class FirebaseConfig {
    static let shared = FirebaseConfig()
    
    let auth: Auth
    let db: Firestore
    let storage: Storage
    let realtimeDB: DatabaseReference
    
    /// Configure Firebase (call this method manually if needed)
    func configure() {
        // Already configured in init
    }
    
    private init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Initialize services
        self.auth = Auth.auth()
        self.db = Firestore.firestore()
        self.storage = Storage.storage()
        self.realtimeDB = Database.database().reference()
        
        // Configure Firestore for offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
        
        print("✅ Firebase initialized successfully")
        print("📱 Project ID: \(FirebaseApp.app()?.options.projectID ?? "unknown")")
    }
}
