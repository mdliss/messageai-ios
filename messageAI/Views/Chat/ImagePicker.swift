//
//  ImagePicker.swift
//  messageAI
//
//  Created by MessageAI Team
//  Image picker wrapper for UIKit
//

import SwiftUI
import PhotosUI

/// SwiftUI wrapper for image picker
struct ImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Text("select photo")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    dismiss()
                }
            }
        }
    }
}

/// Camera picker using UIImagePickerController
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Image picker selector sheet
struct ImagePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                showCamera = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("take photo")
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            Button {
                showPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("choose from library")
                    Spacer()
                }
                .padding()
            }
            
            Divider()
            
            Button(role: .cancel) {
                isPresented = false
            } label: {
                HStack {
                    Text("cancel")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotosPicker(selection: Binding(
                get: { nil },
                set: { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                            isPresented = false
                        }
                    }
                }
            ), matching: .images) {
                Text("select photo")
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedImage)
                .onDisappear {
                    if selectedImage != nil {
                        isPresented = false
                    }
                }
        }
    }
}

