/**
 * Generate embeddings for messages using OpenAI
 */

import * as functions from 'firebase-functions';
import OpenAI from 'openai';

interface Message {
  id: string;
  text: string;
  type: 'text' | 'image';
  conversationId: string;
  embedding?: number[];
}

/**
 * Generate embedding for new text messages
 * Trigger: onCreate conversations/{conversationId}/messages/{messageId}
 */
export const generateMessageEmbedding = functions
  .runWith({
    timeoutSeconds: 10,
    memory: '256MB',
  })
  .firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const messageId = context.params.messageId;
    const conversationId = context.params.conversationId;
    
    // Only generate embeddings for text messages
    if (message.type !== 'text' || !message.text) {
      console.log(`ℹ️ Skipping embedding for non-text message: ${messageId}`);
      return;
    }
    
    // Skip if embedding already exists
    if (message.embedding && message.embedding.length > 0) {
      console.log(`ℹ️ Embedding already exists for message: ${messageId}`);
      return;
    }
    
    try {
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        console.log('⚠️ OpenAI API key not configured, skipping embedding generation');
        return;
      }
      
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      console.log(`🔄 Generating embedding for message: ${messageId}`);
      const startTime = Date.now();
      
      // Generate embedding using text-embedding-3-small model (1536 dimensions)
      const response = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: message.text,
        encoding_format: 'float',
      });
      
      const embedding = response.data[0].embedding;
      const latency = Date.now() - startTime;
      
      // Update message document with embedding
      await snapshot.ref.update({
        embedding: embedding
      });
      
      console.log(`✅ Embedding generated for message ${messageId} in ${latency}ms`);
      console.log(`   Embedding dimensions: ${embedding.length}`);
      console.log(`   Conversation: ${conversationId}`);
      
    } catch (error: any) {
      // Log error but don't fail the message delivery
      console.error(`❌ Failed to generate embedding for message ${messageId}:`, error.message);
      console.error('   Stack:', error.stack);
      
      // Don't throw - we don't want to block message delivery
      // The message will still exist, just without an embedding
      // Search can fall back to keyword matching
    }
  });

