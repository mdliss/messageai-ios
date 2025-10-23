//
//  ProfileEditingViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for profile editing operations
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
class ProfileEditingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = FirebaseConfig.shared.db
    private let storageService = StorageService.shared
    
    // MARK: - Update Display Name
    
    /// Update user's display name
    /// - Parameters:
    ///   - userId: User ID
    ///   - newDisplayName: New display name
    func updateDisplayName(userId: String, newDisplayName: String) async throws {
        print("💾 Updating display name to: \(newDisplayName)")
        
        // Validate input
        let trimmedName = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProfileEditingError.emptyName
        }
        
        guard trimmedName.count <= 50 else {
            throw ProfileEditingError.nameTooLong
        }
        
        isLoading = true
        
        do {
            // Update Firestore
            try await db.collection("users").document(userId).updateData([
                "displayName": trimmedName
            ])
            
            // Update all conversations where user is participant
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .getDocuments()
            
            print("📝 Updating display name in \(conversationsSnapshot.documents.count) conversations")
            
            // Update participantDetails in each conversation
            for conversationDoc in conversationsSnapshot.documents {
                try await conversationDoc.reference.updateData([
                    "participantDetails.\(userId).displayName": trimmedName
                ])
            }
            
            print("✅ Display name updated successfully")
            
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Failed to update display name: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Update Profile Picture
    
    /// Update user's profile picture
    /// - Parameters:
    ///   - userId: User ID
    ///   - avatarType: Type of avatar (built-in or custom)
    ///   - avatarId: Avatar ID for built-in avatars
    ///   - customImage: UIImage for custom photo upload
    func updateProfilePicture(
        userId: String,
        avatarType: AvatarType,
        avatarId: String? = nil,
        customImage: UIImage? = nil
    ) async throws {
        print("🖼️ Updating profile picture - Type: \(avatarType.rawValue)")
        
        isLoading = true
        
        do {
            var updateData: [String: Any] = [
                "avatarType": avatarType.rawValue
            ]
            
            switch avatarType {
            case .builtIn:
                guard let avatarId = avatarId else {
                    throw ProfileEditingError.missingAvatarId
                }
                
                // Validate avatar ID exists
                guard BuiltInAvatars.avatar(for: avatarId) != nil else {
                    throw ProfileEditingError.invalidAvatarId
                }
                
                updateData["avatarId"] = avatarId
                
                print("💾 Saving built-in avatar: \(avatarId)")
                
            case .custom:
                guard let image = customImage else {
                    throw ProfileEditingError.missingCustomImage
                }
                
                // Upload image to Firebase Storage
                let storagePath = "users/\(userId)/profile.jpg"
                let photoURL = try await storageService.uploadImage(image, path: storagePath)
                
                updateData["photoURL"] = photoURL
                updateData["avatarId"] = nil  // Clear built-in avatar ID
                
                print("📤 Uploaded custom photo: \(photoURL)")
            }
            
            // Update Firestore user document
            try await db.collection("users").document(userId).updateData(updateData)
            
            // Update participantDetails in all conversations
            let conversationsSnapshot = try await db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .getDocuments()
            
            print("📝 Updating profile picture in \(conversationsSnapshot.documents.count) conversations")
            
            // For built-in avatars, we don't update photoURL in conversations
            // The app will render the built-in avatar based on user's avatarType + avatarId
            // Only update photoURL for custom images
            if avatarType == .custom, let photoURL = updateData["photoURL"] as? String {
                for conversationDoc in conversationsSnapshot.documents {
                    try await conversationDoc.reference.updateData([
                        "participantDetails.\(userId).photoURL": photoURL
                    ])
                }
            } else if avatarType == .builtIn {
                // For built-in avatars, remove photoURL from conversations
                for conversationDoc in conversationsSnapshot.documents {
                    try await conversationDoc.reference.updateData([
                        "participantDetails.\(userId).photoURL": FieldValue.delete()
                    ])
                }
            }
            
            print("✅ Profile picture updated successfully")
            
            isLoading = false
        } catch {
            isLoading = false
            print("❌ Failed to update profile picture: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Errors

enum ProfileEditingError: LocalizedError {
    case emptyName
    case nameTooLong
    case missingAvatarId
    case invalidAvatarId
    case missingCustomImage
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty"
        case .nameTooLong:
            return "Name must be 50 characters or less"
        case .missingAvatarId:
            return "Avatar ID is required for built-in avatars"
        case .invalidAvatarId:
            return "Invalid avatar ID"
        case .missingCustomImage:
            return "Image is required for custom photo upload"
        }
    }
}

