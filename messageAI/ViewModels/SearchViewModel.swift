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
import FirebaseFunctions

/// Search result from AI search
struct AISearchResult: Identifiable {
    let id: String
    let messageId: String
    let conversationId: String
    let text: String
    let senderName: String
    let timestamp: Date
    let score: Double
    let snippet: String
}

/// ViewModel managing message search
@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [Message] = []
    @Published var aiSearchResults: [AISearchResult] = []
    @Published var isSearching = false
    @Published var searchQuery = ""
    @Published var useAISearch = true  // Toggle between AI and keyword search
    @Published var currentUserId: String?  // Track current user for conversation filtering
    @Published var ragAnswers: [String: String] = [:]  // NEW: Conversation ID -> RAG answer
    
    private let coreDataService = CoreDataService.shared
    private let functions = Functions.functions()
    
    // MARK: - Search
    
    /// Search messages by query using AI or keyword search
    /// - Parameter query: Search query
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Clear results immediately when query is empty
            await MainActor.run {
                searchResults = []
                aiSearchResults = []
            }
            return
        }
        
        // Set loading state and CLEAR old results immediately
        await MainActor.run {
            isSearching = true
            searchResults = []
            aiSearchResults = []
        }
        
        print("🔍 ═══════════════════════════════════════")
        print("🔍 SEARCH INITIATED")
        print("🔍 Query: \"\(query)\"")
        print("🔍 Mode: \(useAISearch ? "AI SEMANTIC SEARCH" : "KEYWORD SEARCH")")
        print("🔍 User ID: \(currentUserId ?? "NOT SET")")
        print("🔍 ═══════════════════════════════════════")
        
        if useAISearch {
            // AI semantic search across user's conversations
            await searchWithAI(query: query)
        } else {
            // Fallback: keyword search in Core Data
            let results = coreDataService.searchMessages(query: query)
            await MainActor.run {
                searchResults = results
            }
        }
        
        await MainActor.run {
            isSearching = false
        }
        
        let resultCount = useAISearch ? aiSearchResults.count : searchResults.count
        print("🔍 ═══════════════════════════════════════")
        print("🔍 SEARCH COMPLETE")
        print("🔍 Results found: \(resultCount)")
        print("🔍 ═══════════════════════════════════════")
    }
    
    /// AI semantic search across conversations
    private func searchWithAI(query: String) async {
        guard let userId = currentUserId else {
            print("❌ No user ID set for search")
            // Fallback to Core Data
            let results = coreDataService.searchMessages(query: query)
            searchResults = results
            return
        }
        
        do {
            print("🔍 Starting AI semantic search for user: \(userId)")
            print("   Query: \"\(query)\"")
            
            // Get ONLY current user's conversations
            let conversationsRef = FirebaseConfig.shared.db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
            let snapshot = try await conversationsRef.getDocuments()
            
            print("📊 Found \(snapshot.documents.count) conversations to search")
            
            var allResults: [AISearchResult] = []
            
            // Search each conversation
            for (index, doc) in snapshot.documents.enumerated() {
                let conversationId = doc.documentID
                
                print("🔍 [AI Search] Conversation \(index + 1)/\(snapshot.documents.count): \(conversationId)")
                
                do {
                    print("   📡 Calling ragSearch Cloud Function...")
                    
                    let result = try await functions.httpsCallable("ragSearch").call([
                        "conversationId": conversationId,
                        "query": query,
                        "limit": 5
                    ])
                    
                    print("   ✅ Cloud Function returned")
                    
                    guard let data = result.data as? [String: Any] else {
                        print("   ⚠️ Invalid response format from Cloud Function")
                        continue
                    }
                    
                    // Extract RAG answer for this conversation
                    // CRITICAL FIX: Only store answer if it's not a "couldn't find" response
                    if let answer = data["answer"] as? String {
                        // Skip storing if it's a generic "no results" message
                        let isNoResultsMessage = answer.lowercased().contains("couldn't find") ||
                                                 answer.lowercased().contains("no relevant") ||
                                                 answer.lowercased().contains("don't contain") ||
                                                 answer.lowercased().contains("no messages found")
                        
                        if !isNoResultsMessage {
                            await MainActor.run {
                                ragAnswers[conversationId] = answer
                            }
                            print("   💡 RAG Answer stored: \(answer)")
                        } else {
                            print("   ℹ️ Skipping no-results answer to avoid duplicates")
                        }
                    }
                    
                    // Extract sources
                    guard let sourcesData = data["sources"] as? [[String: Any]] else {
                        print("   ⚠️ No sources in response")
                        continue
                    }
                    
                    print("   📊 Got \(sourcesData.count) source messages from this conversation")
                    
                    // Parse source messages
                    let conversationResults = sourcesData.compactMap { sourceDict -> AISearchResult? in
                        guard let messageId = sourceDict["messageId"] as? String,
                              let text = sourceDict["text"] as? String,
                              let senderName = sourceDict["senderName"] as? String,
                              let timestampStr = sourceDict["timestamp"] as? String,
                              let score = sourceDict["score"] as? Double,
                              let snippet = sourceDict["snippet"] as? String else {
                            return nil
                        }
                        
                        let formatter = ISO8601DateFormatter()
                        let timestamp = formatter.date(from: timestampStr) ?? Date()
                        
                        return AISearchResult(
                            id: "\(conversationId)_\(messageId)",
                            messageId: messageId,
                            conversationId: conversationId,
                            text: text,
                            senderName: senderName,
                            timestamp: timestamp,
                            score: score,
                            snippet: snippet
                        )
                    }
                    
                    allResults.append(contentsOf: conversationResults)
                    
                } catch {
                    print("⚠️ Failed to search conversation \(conversationId): \(error.localizedDescription)")
                    continue
                }
            }
            
            // Sort by relevance score and update on main actor
            await MainActor.run {
                aiSearchResults = allResults.sorted { $0.score > $1.score }
            }
            
            print("✅ AI search complete: \(allResults.count) total results")
            
        } catch {
            print("❌ AI search failed: \(error.localizedDescription)")
            // Fallback to Core Data search
            let results = coreDataService.searchMessages(query: query)
            await MainActor.run {
                searchResults = results
            }
        }
    }
    
    /// Clear search
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        aiSearchResults = []
        ragAnswers = [:]
    }
    
    /// Group results by conversation (for keyword search)
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
    
    /// Group AI search results by conversation
    func groupedAIResults() -> [String: [AISearchResult]] {
        var grouped: [String: [AISearchResult]] = [:]
        
        for result in aiSearchResults {
            if grouped[result.conversationId] == nil {
                grouped[result.conversationId] = []
            }
            grouped[result.conversationId]?.append(result)
        }
        
        return grouped
    }
}

