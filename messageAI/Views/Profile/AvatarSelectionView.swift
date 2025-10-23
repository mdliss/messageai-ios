//
//  AvatarSelectionView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Avatar selection sheet for profile editing
//

import SwiftUI
import PhotosUI

struct AvatarSelectionView: View {
    let currentUserId: String
    @Binding var isPresented: Bool
    let onAvatarSelected: () -> Void
    
    @StateObject private var viewModel = ProfileEditingViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedBuiltInAvatar: BuiltInAvatar?
    @State private var showPhotosPicker = false
    @State private var isUploading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Built-in avatars section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("choose from built-in avatars")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("instant selection, no upload needed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 16) {
                            ForEach(BuiltInAvatars.all) { avatar in
                                Button {
                                    selectedBuiltInAvatar = avatar
                                } label: {
                                    VStack(spacing: 4) {
                                        BuiltInAvatarView(avatar: avatar, size: 60)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.blue, lineWidth: selectedBuiltInAvatar?.id == avatar.id ? 3 : 0)
                                            )
                                        
                                        if selectedBuiltInAvatar?.id == avatar.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                                .font(.caption)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Photo library section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("upload from photo library")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("upload a custom photo from your device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        Button {
                            showPhotosPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo")
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("select from photo library")
                                        .font(.subheadline.weight(.semibold))
                                    Text("jpg, png, heic supported")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("choose avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        saveBuiltInAvatar()
                    }
                    .disabled(selectedBuiltInAvatar == nil && !isUploading)
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, newPhoto in
                if let newPhoto = newPhoto {
                    uploadPhoto(newPhoto)
                }
            }
            .overlay {
                if isUploading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("uploading photo...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(Color(.systemGray3))
                        .cornerRadius(16)
                    }
                }
            }
            .alert("upload failed", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("ok") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Save Built-in Avatar
    
    private func saveBuiltInAvatar() {
        guard let avatar = selectedBuiltInAvatar else {
            isPresented = false
            return
        }
        
        print("💾 Saving built-in avatar: \(avatar.name) (\(avatar.id))")
        
        Task {
            do {
                try await viewModel.updateProfilePicture(
                    userId: currentUserId,
                    avatarType: .builtIn,
                    avatarId: avatar.id
                )
                
                print("✅ Built-in avatar saved successfully")
                
                await MainActor.run {
                    onAvatarSelected()
                    isPresented = false
                }
            } catch {
                print("❌ Failed to save built-in avatar: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upload Photo
    
    private func uploadPhoto(_ photoItem: PhotosPickerItem) {
        print("📤 Starting photo upload...")
        
        isUploading = true
        
        Task {
            do {
                // Load image data
                guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                    throw PhotoUploadError.invalidData
                }
                
                guard let image = UIImage(data: imageData) else {
                    throw PhotoUploadError.invalidImage
                }
                
                print("📸 Loaded image: \(image.size.width)x\(image.size.height)")
                
                // Compress and resize image
                guard let compressedImage = ImageCompressor.compressAndResize(image, maxDimension: 1024, maxSizeKB: 1000) else {
                    throw PhotoUploadError.invalidImage
                }
                
                print("🗜️ Compressed image to reasonable size")
                
                // Upload to Firebase Storage
                try await viewModel.updateProfilePicture(
                    userId: currentUserId,
                    avatarType: .custom,
                    customImage: compressedImage
                )
                
                print("✅ Photo uploaded successfully")
                
                await MainActor.run {
                    isUploading = false
                    onAvatarSelected()
                    isPresented = false
                }
            } catch {
                print("❌ Photo upload failed: \(error.localizedDescription)")
                
                await MainActor.run {
                    isUploading = false
                    viewModel.errorMessage = "Failed to upload photo. Please try again."
                }
            }
        }
    }
}

enum PhotoUploadError: LocalizedError {
    case invalidData
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Failed to load photo data"
        case .invalidImage:
            return "Failed to process image"
        }
    }
}

#Preview {
    AvatarSelectionView(
        currentUserId: "user1",
        isPresented: .constant(true),
        onAvatarSelected: {}
    )
}

