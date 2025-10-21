//
//  SearchViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel for message search
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing message search
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [Message] = []
    @Published var isSearching = false
    @Published var searchQuery = ""
    
    private let coreDataService = CoreDataService.shared
    
    // MARK: - Search
    
    /// Search messages by query
    /// - Parameter query: Search query
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchQuery = query
        
        // Search in Core Data
        let results = coreDataService.searchMessages(query: query)
        searchResults = results
        
        isSearching = false
        
        print("🔍 Search completed: \(results.count) results for '\(query)'")
    }
    
    /// Clear search
    func clearSearch() {
        searchQuery = ""
        searchResults = []
    }
    
    /// Group results by conversation
    func groupedResults() -> [String: [Message]] {
        var grouped: [String: [Message]] = [:]
        
        for message in searchResults {
            if grouped[message.conversationId] == nil {
                grouped[message.conversationId] = []
            }
            grouped[message.conversationId]?.append(message)
        }
        
        return grouped
    }
}

