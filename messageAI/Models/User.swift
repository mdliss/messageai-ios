//
//  User.swift
//  messageAI
//
//  Created by MessageAI Team
//  User model matching Firestore schema
//

import Foundation
import FirebaseAuth

/// Avatar type enum
enum AvatarType: String, Codable {
    case builtIn = "built_in"
    case custom = "custom"
}

/// User model representing a user in the MessageAI system
struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    var displayName: String
    let photoURL: String?
    var avatarType: AvatarType?
    var avatarId: String?
    var isOnline: Bool
    var lastSeen: Date
    var fcmToken: String?
    let createdAt: Date
    var preferences: UserPreferences
    
    /// Initialize from Firebase Auth User
    init(from firebaseUser: FirebaseAuth.User, preferences: UserPreferences = UserPreferences()) {
        self.id = firebaseUser.uid
        self.email = firebaseUser.email ?? ""
        self.displayName = firebaseUser.displayName ?? User.generateDisplayName(from: firebaseUser.email ?? "")
        self.photoURL = firebaseUser.photoURL?.absoluteString
        self.avatarType = nil
        self.avatarId = nil
        self.isOnline = true
        self.lastSeen = Date()
        self.fcmToken = nil
        self.createdAt = Date()
        self.preferences = preferences
    }
    
    /// Initialize with all parameters
    init(id: String, email: String, displayName: String, photoURL: String? = nil,
         avatarType: AvatarType? = nil, avatarId: String? = nil,
         isOnline: Bool = false, lastSeen: Date = Date(), fcmToken: String? = nil,
         createdAt: Date = Date(), preferences: UserPreferences = UserPreferences()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.avatarType = avatarType
        self.avatarId = avatarId
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.fcmToken = fcmToken
        self.createdAt = createdAt
        self.preferences = preferences
    }
    
    /// Generate display name from email prefix
    static func generateDisplayName(from email: String) -> String {
        let components = email.components(separatedBy: "@")
        guard let prefix = components.first, !prefix.isEmpty else {
            return "User"
        }
        // Capitalize first letter
        return prefix.prefix(1).uppercased() + prefix.dropFirst()
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "isOnline": isOnline,
            "lastSeen": lastSeen,
            "createdAt": createdAt,
            "preferences": preferences.toDictionary()
        ]
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        if let fcmToken = fcmToken {
            dict["fcmToken"] = fcmToken
        }
        if let avatarType = avatarType {
            dict["avatarType"] = avatarType.rawValue
        }
        if let avatarId = avatarId {
            dict["avatarId"] = avatarId
        }
        
        return dict
    }
}

/// User preferences for settings and notifications
struct UserPreferences: Codable, Equatable {
    var aiEnabled: Bool
    var notificationSettings: [String: Bool]
    
    init(aiEnabled: Bool = true, notificationSettings: [String: Bool] = [:]) {
        self.aiEnabled = aiEnabled
        self.notificationSettings = notificationSettings
    }
    
    /// Convert to Firestore dictionary
    func toDictionary() -> [String: Any] {
        return [
            "aiEnabled": aiEnabled,
            "notificationSettings": notificationSettings
        ]
    }
}

// MARK: - Firestore Coding Keys
extension User {
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case photoURL
        case avatarType
        case avatarId
        case isOnline
        case lastSeen
        case fcmToken
        case createdAt
        case preferences
    }
}

