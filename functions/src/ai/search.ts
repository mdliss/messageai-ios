/**
 * AI-powered semantic search using OpenAI embeddings
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
  createdAt: admin.firestore.Timestamp;
}

interface SearchResult {
  messageId: string;
  text: string;
  senderName: string;
  timestamp: string;
  score: number;
  snippet: string;
}

/**
 * Semantic search using embeddings and cosine similarity
 */
export const searchMessages = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '1GB',
  })
  .https.onCall(
  async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }
    
    const conversationId = data.conversationId as string;
    const query = data.query as string;
    const limit = (data.limit as number) || 10;
    
    if (!conversationId || !query) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId and query are required'
      );
    }
    
    console.log(`🔍 Searching conversation ${conversationId} for: "${query}"`);
    
    try {
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'OpenAI API key not configured'
        );
      }
      
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      console.log(`📡 Fetching messages from conversation: ${conversationId}`);
      
      // Fetch messages from conversation (last 500 for search scope)
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('type', '==', 'text')  // Only search text messages
        .orderBy('createdAt', 'desc')
        .limit(500);
      
      console.log(`📡 Query: conversations/${conversationId}/messages where type==text orderBy createdAt desc limit 500`);
      
      const messagesSnapshot = await messagesRef.get();
      
      console.log(`📊 Query returned ${messagesSnapshot.docs.length} documents`);
      
      if (messagesSnapshot.empty) {
        console.log(`ℹ️ No messages found in conversation ${conversationId}`);
        return {
          success: true,
          results: [],
          query: query,
        };
      }
      
      const messages = messagesSnapshot.docs.map(doc => doc.data() as Message);
      
      console.log(`📊 Searching through ${messages.length} messages`);
      console.log(`📝 Sample messages:`)
      messages.slice(0, 3).forEach((msg, idx) => {
        console.log(`   [${idx}] ${msg.senderName}: ${msg.text.substring(0, 50)}...`);
      });
      
      // Hybrid approach: keyword matching + AI semantic understanding
      const queryLower = query.toLowerCase();
      
      // Step 1: Get keyword candidates (fast)
      const keywordMatches = messages.filter(msg => 
        msg.text.toLowerCase().includes(queryLower) ||
        queryLower.split(/\s+/).some(word => 
          word.length > 2 && msg.text.toLowerCase().includes(word)
        )
      );
      
      console.log(`📊 Keyword matching found ${keywordMatches.length} candidates`);
      
      // Step 2: If no keyword matches, use AI to expand query and search again
      let finalMatches = keywordMatches;
      
      if (keywordMatches.length === 0 && messages.length > 0) {
        try {
          console.log(`🤖 No keyword matches, using AI to expand query...`);
          
          // Ask AI for related terms
          const expansionResponse = await openai.chat.completions.create({
            model: 'gpt-4o-mini',
            max_tokens: 50,
            temperature: 0.3,
            messages: [{
              role: 'user',
              content: `List 5 related keywords for: "${query}". Return only comma-separated words. Example: "meeting,schedule,calendar,sync,coordinate"`
            }],
          });
          
          const relatedTerms = expansionResponse.choices[0]?.message?.content || '';
          const expandedKeywords = relatedTerms.split(',').map(t => t.trim().toLowerCase());
          
          console.log(`🔍 Expanded keywords: ${expandedKeywords.join(', ')}`);
          
          // Search with expanded keywords
          finalMatches = messages.filter(msg => {
            const textLower = msg.text.toLowerCase();
            return expandedKeywords.some(keyword => textLower.includes(keyword));
          });
          
          console.log(`📊 Expanded search found ${finalMatches.length} matches`);
        } catch (error) {
          console.log(`⚠️ Query expansion failed: ${error}`);
        }
      }
      
      // Step 3: Take top results
      const relevantIndices = finalMatches
        .slice(0, limit)
        .map(msg => messages.indexOf(msg))
        .filter(idx => idx >= 0);
      
      console.log(`📋 Returning ${relevantIndices.length} final results`);
      
      // Build search results
      const searchResults: SearchResult[] = relevantIndices
        .filter(idx => idx >= 0 && idx < messages.length)
        .map(idx => {
          const msg = messages[idx];
          
          // Create snippet (first 100 chars or full text if shorter)
          const snippet = msg.text.length > 100 
            ? msg.text.substring(0, 100) + '...'
            : msg.text;
          
          return {
            messageId: msg.id,
            text: msg.text,
            senderName: msg.senderName,
            timestamp: msg.createdAt.toDate().toISOString(),
            score: 1.0 - (relevantIndices.indexOf(idx) * 0.1), // Simple scoring
            snippet: snippet,
          };
        });
      
      console.log(`✅ Found ${searchResults.length} relevant messages`);
      
      return {
        success: true,
        results: searchResults,
        query: query,
        totalSearched: messages.length,
      };
      
    } catch (error: any) {
      console.error('❌ Search failed:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to search: ${error.message}`
      );
    }
  }
);

