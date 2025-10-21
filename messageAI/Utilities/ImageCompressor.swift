//
//  ImageCompressor.swift
//  messageAI
//
//  Created by MessageAI Team
//  Utility for compressing images
//

import UIKit

/// Utility for image compression
struct ImageCompressor {
    
    /// Compress image to target size
    /// - Parameters:
    ///   - image: Original image
    ///   - maxSizeKB: Maximum size in kilobytes
    /// - Returns: Compressed image data
    static func compress(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compression)
        
        // Iteratively compress until under max size
        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }
    
    /// Resize image to max dimension
    /// - Parameters:
    ///   - image: Original image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image
    static func resize(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        
        // If image is already smaller, return it
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }
        
        // Resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    /// Compress and resize image
    /// - Parameters:
    ///   - image: Original image
    ///   - maxDimension: Maximum width or height
    ///   - maxSizeKB: Maximum size in kilobytes
    /// - Returns: Compressed and resized image
    static func compressAndResize(_ image: UIImage, maxDimension: CGFloat = 1024, maxSizeKB: Int = 500) -> UIImage? {
        let resized = resize(image, maxDimension: maxDimension)
        
        guard let data = compress(resized, maxSizeKB: maxSizeKB),
              let compressed = UIImage(data: data) else {
            return nil
        }
        
        return compressed
    }
}

