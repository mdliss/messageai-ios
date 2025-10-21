/**
 * Detect priority/urgent messages
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Anthropic from '@anthropic-ai/sdk';

interface Message {
  id: string;
  text: string;
  type: 'text' | 'image';
}

/**
 * Detect if message is urgent and flag it
 */
export const detectPriority = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    
    // Only check text messages
    if (message.type !== 'text') {
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for obvious urgent keywords
    const urgentKeywords = [
      'urgent',
      'asap',
      'critical',
      'emergency',
      'immediately',
      'right now',
      'deadline',
      'blocker',
      'breaking',
    ];
    
    const hasUrgentKeyword = urgentKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (hasUrgentKeyword) {
      // Mark as priority
      await snapshot.ref.update({
        priority: true,
      });
      
      console.log(`🚨 Message marked as priority: ${message.id}`);
      return;
    }
    
    // For ambiguous cases, use AI (optional - can be skipped for MVP)
    // This adds latency, so only use if needed
    const ambiguousKeywords = ['important', 'need', 'must', 'should'];
    const hasAmbiguousKeyword = ambiguousKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (hasAmbiguousKeyword) {
      try {
        const apiKey = functions.config().anthropic?.key;
        
        if (!apiKey) {
          console.log('ℹ️ Anthropic API key not configured, skipping AI priority detection');
          return;
        }
        
        const anthropic = new Anthropic({
          apiKey: apiKey,
        });
        
        const response = await anthropic.messages.create({
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 50,
          messages: [{
            role: 'user',
            content: `Rate the urgency of this message on a scale of 1-5, where 5 is extremely urgent and 1 is casual. Only respond with a number.\n\nMessage: "${message.text}"`,
          }],
        });
        
        const rating = response.content[0].type === 'text' 
          ? parseInt(response.content[0].text.trim()) 
          : 0;
        
        if (rating >= 4) {
          await snapshot.ref.update({
            priority: true,
          });
          
          console.log(`🚨 Message marked as priority (AI rating: ${rating}): ${message.id}`);
        }
        
      } catch (error) {
        console.error('❌ AI priority detection failed:', error);
      }
    }
  });

