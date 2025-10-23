/**
 * RAG (Retrieval-Augmented Generation) Search for MessageAI
 * 
 * Implements semantic search using:
 * 1. OpenAI embeddings (text-embedding-3-small)
 * 2. Cosine similarity for vector search
 * 3. GPT-4 for contextual answer generation
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import OpenAI from 'openai';
import { cosineSimilarity } from '../utils/similarity';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
  createdAt: admin.firestore.Timestamp;
  embedding?: number[];
}

interface SearchResult {
  messageId: string;
  text: string;
  senderName: string;
  timestamp: string;
  score: number;
  snippet: string;
  vectorScore?: number;
  keywordScore?: number;
}

/**
 * Calculate keyword match score for a message
 * Returns score between 0.0 and 1.0 based on keyword presence
 * 
 * @param messageText - The message text to search in
 * @param query - The search query
 * @returns Keyword match score (0.0 to 1.0)
 */
function calculateKeywordScore(messageText: string, query: string): number {
  const messageLower = messageText.toLowerCase();
  const queryLower = query.toLowerCase();
  const queryWords = queryLower.split(/\s+/).filter(w => w.length > 0);
  
  if (queryWords.length === 0) return 0;
  
  let score = 0;
  
  // Exact full query match: +0.5
  if (messageLower.includes(queryLower)) {
    score += 0.5;
  }
  
  // Count matching words
  let matchingWords = 0;
  for (const word of queryWords) {
    if (messageLower.includes(word)) {
      matchingWords++;
      
      // Exact word boundary match: +0.1 per word (up to 0.3)
      const wordRegex = new RegExp(`\\b${word}\\b`, 'i');
      if (wordRegex.test(messageText)) {
        score += 0.1;
      } else {
        // Partial match: +0.05 per word
        score += 0.05;
      }
    }
  }
  
  // Bonus for matching all query words: +0.2
  if (matchingWords === queryWords.length) {
    score += 0.2;
  }
  
  // Cap at 1.0
  return Math.min(score, 1.0);
}

/**
 * RAG-based semantic search
 * 
 * Process:
 * 1. Generate embedding for search query
 * 2. Fetch messages with embeddings from Firestore
 * 3. Calculate cosine similarity for each message
 * 4. Retrieve top 10 most similar messages
 * 5. Feed messages to GPT-4 as context
 * 6. Return LLM-generated answer + source messages
 */
export const ragSearch = functions
  .runWith({
    timeoutSeconds: 30,
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
    
    console.log(`🔍 RAG Search: "${query}" in conversation ${conversationId}`);
    const overallStartTime = Date.now();
    
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
      
      // STEP 1: Generate embedding for search query
      console.log(`🔄 Generating query embedding...`);
      const embeddingStartTime = Date.now();
      
      const queryEmbeddingResponse = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: query,
        encoding_format: 'float',
      });
      
      const queryEmbedding = queryEmbeddingResponse.data[0].embedding;
      const embeddingLatency = Date.now() - embeddingStartTime;
      console.log(`✅ Query embedding generated in ${embeddingLatency}ms (${queryEmbedding.length} dimensions)`);
      
      // STEP 2: Fetch messages with embeddings
      console.log(`📡 Fetching messages with embeddings...`);
      const fetchStartTime = Date.now();
      
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('type', '==', 'text')
        .orderBy('createdAt', 'desc')
        .limit(500);
      
      const messagesSnapshot = await messagesRef.get();
      const fetchLatency = Date.now() - fetchStartTime;
      
      console.log(`📊 Fetched ${messagesSnapshot.docs.length} messages in ${fetchLatency}ms`);
      
      if (messagesSnapshot.empty) {
        console.log(`ℹ️ No messages found in conversation ${conversationId}`);
        return {
          success: true,
          answer: 'No messages found to search.',
          sources: [],
          query: query,
          stats: {
            totalMessages: 0,
            messagesWithEmbeddings: 0,
            embeddingLatency: embeddingLatency,
            searchLatency: 0,
            llmLatency: 0,
            totalLatency: Date.now() - overallStartTime
          }
        };
      }
      
      // STEP 3: Calculate HYBRID scores (vector similarity + keyword matching)
      console.log(`🔄 Calculating hybrid scores (vector + keyword)...`);
      const similarityStartTime = Date.now();
      
      const messagesWithSimilarity = messagesSnapshot.docs
        .map(doc => {
          const message = doc.data() as Message;
          
          // Skip messages without embeddings
          if (!message.embedding || message.embedding.length === 0) {
            return null;
          }
          
          // Calculate vector similarity (semantic search)
          const vectorScore = cosineSimilarity(queryEmbedding, message.embedding);
          
          // Calculate keyword match score (exact/partial matching)
          const keywordScore = calculateKeywordScore(message.text, query);
          
          // HYBRID SCORING: 60% vector similarity + 40% keyword matching
          // This ensures exact keyword matches rank higher while preserving semantic search benefits
          const hybridScore = (vectorScore * 0.6) + (keywordScore * 0.4);
          
          return {
            message,
            vectorScore,
            keywordScore,
            hybridScore
          };
        })
        .filter((item): item is { 
          message: Message; 
          vectorScore: number;
          keywordScore: number;
          hybridScore: number;
        } => item !== null);
      
      const messagesWithEmbeddings = messagesWithSimilarity.length;
      const similarityLatency = Date.now() - similarityStartTime;
      
      console.log(`✅ Calculated ${messagesWithEmbeddings} hybrid scores in ${similarityLatency}ms`);
      console.log(`   Messages with embeddings: ${messagesWithEmbeddings}/${messagesSnapshot.docs.length}`);
      
      // If no messages have embeddings, fall back to keyword search
      if (messagesWithSimilarity.length === 0) {
        console.log(`⚠️ No messages with embeddings found, falling back to keyword search`);
        
        const allMessages = messagesSnapshot.docs.map(doc => doc.data() as Message);
        const queryLower = query.toLowerCase();
        
        const keywordMatches = allMessages
          .filter(msg => msg.text.toLowerCase().includes(queryLower))
          .slice(0, limit);
        
        const keywordResults: SearchResult[] = keywordMatches.map(msg => ({
          messageId: msg.id,
          text: msg.text,
          senderName: msg.senderName,
          timestamp: msg.createdAt.toDate().toISOString(),
          score: 0.5, // Fixed score for keyword matches
          snippet: msg.text.length > 100 ? msg.text.substring(0, 100) + '...' : msg.text
        }));
        
        return {
          success: true,
          answer: `Found ${keywordResults.length} keyword matches. Note: Semantic search unavailable - embeddings not yet generated for messages.`,
          sources: keywordResults,
          query: query,
          fallbackMode: 'keyword',
          stats: {
            totalMessages: allMessages.length,
            messagesWithEmbeddings: 0,
            embeddingLatency: embeddingLatency,
            searchLatency: Date.now() - similarityStartTime,
            llmLatency: 0,
            totalLatency: Date.now() - overallStartTime
          }
        };
      }
      
      // STEP 4: Sort by hybrid score and take top K
      messagesWithSimilarity.sort((a, b) => b.hybridScore - a.hybridScore);
      const topMatches = messagesWithSimilarity.slice(0, limit);
      
      console.log(`📋 Top ${topMatches.length} matches:`);
      topMatches.forEach((match, idx) => {
        const preview = match.message.text.length > 50 
          ? match.message.text.substring(0, 50) + '...'
          : match.message.text;
        console.log(`   ${idx + 1}. "${preview}"`);
        console.log(`      Hybrid: ${(match.hybridScore * 100).toFixed(1)}% (Vector: ${(match.vectorScore * 100).toFixed(1)}%, Keyword: ${(match.keywordScore * 100).toFixed(1)}%)`);
      });
      
      // STEP 5: Build context for GPT-4
      const contextMessages = topMatches.map(match => ({
        sender: match.message.senderName,
        text: match.message.text,
        timestamp: match.message.createdAt.toDate().toISOString()
      }));
      
      const contextString = contextMessages.map((msg, idx) => 
        `[${idx + 1}] ${msg.sender} (${new Date(msg.timestamp).toLocaleString()}): ${msg.text}`
      ).join('\n\n');
      
      // STEP 6: Call GPT-4 to generate contextual answer
      console.log(`🤖 Generating answer with GPT-4...`);
      const llmStartTime = Date.now();
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 500,
        temperature: 0.7,
        messages: [{
          role: 'system',
          content: 'You are an intelligent search assistant helping remote teams find information in their chat history. Based on the retrieved messages, provide a clear, concise answer to the user\'s query. If the messages don\'t contain relevant information, say so clearly. Never use hyphens. Be helpful and specific.'
        }, {
          role: 'user',
          content: `Based on these messages from our team conversation, answer this query: "${query}"

Retrieved Messages:
${contextString}

Provide a clear, specific answer based on the messages above. If the messages don't contain the answer, say "I couldn't find relevant information about that in the conversation." Never use hyphens.`
        }]
      });
      
      const answer = completion.choices[0]?.message?.content || 'No answer generated.';
      const llmLatency = Date.now() - llmStartTime;
      
      console.log(`✅ Answer generated in ${llmLatency}ms`);
      
      // STEP 7: Build search results with hybrid scores
      const searchResults: SearchResult[] = topMatches.map(match => {
        const msg = match.message;
        const snippet = msg.text.length > 150 
          ? msg.text.substring(0, 150) + '...'
          : msg.text;
        
        return {
          messageId: msg.id,
          text: msg.text,
          senderName: msg.senderName,
          timestamp: msg.createdAt.toDate().toISOString(),
          score: match.hybridScore,  // Use hybrid score for ranking
          snippet: snippet,
          vectorScore: match.vectorScore,  // Include component scores for debugging
          keywordScore: match.keywordScore
        };
      });
      
      const totalLatency = Date.now() - overallStartTime;
      
      console.log(`✅ RAG Search complete in ${totalLatency}ms total`);
      console.log(`   Breakdown: Embedding ${embeddingLatency}ms + Fetch ${fetchLatency}ms + Similarity ${similarityLatency}ms + LLM ${llmLatency}ms`);
      
      return {
        success: true,
        answer: answer,
        sources: searchResults,
        query: query,
        stats: {
          totalMessages: messagesSnapshot.docs.length,
          messagesWithEmbeddings: messagesWithEmbeddings,
          embeddingLatency: embeddingLatency,
          searchLatency: similarityLatency,
          llmLatency: llmLatency,
          totalLatency: totalLatency
        }
      };
      
    } catch (error: any) {
      console.error('❌ RAG Search failed:', error);
      throw new functions.https.HttpsError(
        'internal',
        `RAG search failed: ${error.message}`
      );
    }
  }
);

