//
//  StorageService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Service for Firebase Storage operations
//

import Foundation
import FirebaseStorage
import UIKit

/// Service managing Firebase Storage operations
class StorageService {
    static let shared = StorageService()
    
    private let storage: Storage
    
    private init() {
        self.storage = FirebaseConfig.shared.storage
    }
    
    // MARK: - Image Upload
    
    /// Upload image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - path: Storage path (e.g., "images/conversationId/filename.jpg")
    /// - Returns: Download URL string
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImage
        }
        
        // Create storage reference
        let storageRef = storage.reference().child(path)
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Upload
        do {
            let _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            
            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            
            print("✅ Image uploaded: \(path)")
            return downloadURL.absoluteString
        } catch {
            print("❌ Image upload failed: \(error.localizedDescription)")
            throw StorageError.uploadFailed(error)
        }
    }
    
    /// Upload image for a conversation message
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - conversationId: Conversation ID
    /// - Returns: Download URL string
    func uploadMessageImage(_ image: UIImage, conversationId: String) async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "\(timestamp)_\(UUID().uuidString).jpg"
        let path = "images/\(conversationId)/\(filename)"

        return try await uploadImage(image, path: path)
    }

    // MARK: - Voice Upload

    /// Upload voice memo to Firebase Storage
    /// - Parameters:
    ///   - audioURL: Local file URL of audio recording
    ///   - path: Storage path (e.g., "voice-memos/conversationId/messageId.m4a")
    /// - Returns: Storage path (not download URL)
    func uploadVoiceMemo(audioURL: URL, path: String) async throws -> String {
        // Read audio data
        let audioData = try Data(contentsOf: audioURL)

        // Create storage reference
        let storageRef = storage.reference().child(path)

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"

        // Upload
        do {
            _ = try await storageRef.putDataAsync(audioData, metadata: metadata)
            print("✅ Voice memo uploaded: \(path)")
            return path
        } catch {
            print("❌ Voice memo upload failed: \(error.localizedDescription)")
            throw StorageError.uploadFailed(error)
        }
    }
    
    // MARK: - Image Delete
    
    /// Delete image from Firebase Storage
    /// - Parameter path: Storage path
    func deleteImage(path: String) async throws {
        let storageRef = storage.reference().child(path)
        
        do {
            try await storageRef.delete()
            print("✅ Image deleted: \(path)")
        } catch {
            print("❌ Image deletion failed: \(error.localizedDescription)")
            throw StorageError.deletionFailed(error)
        }
    }
    
    /// Delete image by URL
    /// - Parameter urlString: Download URL string
    func deleteImageByURL(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }
        
        let storageRef = storage.reference(forURL: urlString)
        
        do {
            try await storageRef.delete()
            print("✅ Image deleted: \(urlString)")
        } catch {
            print("❌ Image deletion failed: \(error.localizedDescription)")
            throw StorageError.deletionFailed(error)
        }
    }
}

// MARK: - Storage Errors

enum StorageError: LocalizedError {
    case invalidImage
    case uploadFailed(Error)
    case deletionFailed(Error)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Deletion failed: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid storage URL"
        }
    }
}

