//
//  Constants.swift
//  messageAI
//
//  Created by MessageAI Team
//  App-wide constants
//

import Foundation

struct Constants {
    
    // MARK: - App Info
    
    static let appName = "MessageAI"
    static let appVersion = "1.0.0"
    
    // MARK: - Message Limits
    
    static let maxMessageLength = 5000
    static let maxImageSizeKB = 5000
    static let messagesPerPage = 50
    
    // MARK: - Timeouts
    
    static let typingIndicatorTimeout: TimeInterval = 3.0
    static let typingDebounceInterval: TimeInterval = 0.5
    static let messageSendTimeout: TimeInterval = 30.0
    
    // MARK: - Retry Logic
    
    static let maxRetryAttempts = 3
    static let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - Image Compression
    
    static let maxImageDimension: CGFloat = 1024
    static let imageCompressionQuality: CGFloat = 0.8
    
    // MARK: - AI Features
    
    static let maxMessagesForAI = 100
    static let aiResponseTimeout: TimeInterval = 30.0
}

