import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseDatabase
import FirebaseFunctions

final class FirebaseConfig {
    static let shared = FirebaseConfig()

    let auth: Auth
    let db: Firestore
    let storage: Storage
    let realtimeDB: DatabaseReference
    let functions: Functions
    
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

        // Initialize Cloud Functions for us-central1 region
        self.functions = Functions.functions(region: "us-central1")

        // Initialize Realtime Database with URL from GoogleService-Info.plist
        if let databaseURL = FirebaseApp.app()?.options.databaseURL {
            print("📍 Realtime Database URL: \(databaseURL)")
            self.realtimeDB = Database.database(url: databaseURL).reference()
        } else {
            print("⚠️ No database URL found in GoogleService-Info.plist")
            print("   Using default Realtime DB reference")
            self.realtimeDB = Database.database().reference()
        }

        // Configure Firestore for offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings

        print("✅ Firebase initialized successfully")
        print("📱 Project ID: \(FirebaseApp.app()?.options.projectID ?? "unknown")")
        print("🔥 Realtime DB URL: \(self.realtimeDB.url)")
        print("⚡ Cloud Functions region: us-central1")
    }
}
