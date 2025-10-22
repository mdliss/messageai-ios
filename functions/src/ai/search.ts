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
      
      // Fetch messages from conversation (last 500 for search scope)
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('type', '==', 'text')  // Only search text messages
        .orderBy('createdAt', 'desc')
        .limit(500);
      
      const messagesSnapshot = await messagesRef.get();
      
      if (messagesSnapshot.empty) {
        return {
          success: true,
          results: [],
          query: query,
        };
      }
      
      const messages = messagesSnapshot.docs.map(doc => doc.data() as Message);
      
      console.log(`📊 Searching through ${messages.length} messages`);
      
      // For MVP: Use GPT to rerank instead of generating embeddings for all messages
      // This is faster and more cost effective for smaller message sets
      // Future enhancement: Generate embeddings for all messages and use cosine similarity
      
      // Build context with recent messages
      const messageContext = messages.slice(0, 50).map((msg, idx) => 
        `[${idx}] ${msg.senderName}: ${msg.text}`
      ).join('\n');
      
      // Use GPT to find relevant messages
      const rerankedResponse = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        max_tokens: 1000,
        temperature: 0.3,
        messages: [{
          role: 'system',
          content: 'You are a semantic search assistant. Given a query and a list of messages, identify the most relevant messages by their index numbers. Return ONLY a JSON array of index numbers in order of relevance. Never use hyphens.',
        }, {
          role: 'user',
          content: `Query: "${query}"

Messages:
${messageContext}

Return the indices of the top ${limit} most relevant messages as a JSON array. Example: [5, 12, 3, 8]

Only return the JSON array, nothing else.`,
        }],
      });
      
      const rerankedText = rerankedResponse.choices[0]?.message?.content || '[]';
      
      // Parse the JSON array of indices
      let relevantIndices: number[] = [];
      try {
        relevantIndices = JSON.parse(rerankedText.trim());
      } catch (error) {
        console.error('❌ Failed to parse reranked results, falling back to keyword search');
        // Fallback: simple keyword matching
        const queryLower = query.toLowerCase();
        const keywordMatches = messages
          .map((msg, idx) => ({ msg, idx }))
          .filter(({msg}) => msg.text.toLowerCase().includes(queryLower))
          .slice(0, limit)
          .map(({idx}) => idx);
        relevantIndices = keywordMatches;
      }
      
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

