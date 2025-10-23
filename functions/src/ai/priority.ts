/**
 * Detect priority/urgent messages using OpenAI GPT
 */

import * as functions from 'firebase-functions';
import OpenAI from 'openai';

interface Message {
  id: string;
  text: string;
  type: 'text' | 'image';
}

/**
 * Detect if message is urgent and flag it
 */
export const detectPriority = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .firestore
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
      // Mark as URGENT priority
      await snapshot.ref.update({
        priority: 'urgent',
      });
      
      console.log(`🚨 Message marked as URGENT: ${message.id}`);
      return;
    }
    
    // Check for HIGH priority keywords
    const highPriorityKeywords = [
      'important',
      'need to',
      'should',
      'must',
      '?',  // Questions often need responses
      '@',  // Mentions
    ];
    
    const hasHighPriorityKeyword = highPriorityKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    // For ambiguous high-priority cases, use AI to confirm
    if (hasHighPriorityKeyword) {
      try {
        const apiKey = functions.config().openai?.key;
        
        if (!apiKey) {
          console.log('ℹ️ OpenAI API key not configured, marking as HIGH based on keywords');
          await snapshot.ref.update({
            priority: 'high',
          });
          return;
        }
        
        const openai = new OpenAI({
          apiKey: apiKey,
        });
        
        const response = await openai.chat.completions.create({
          model: 'gpt-4o-mini',
          max_tokens: 50,
          temperature: 0.3,
          messages: [{
            role: 'user',
            content: `Rate the urgency of this message on a scale of 1-5, where 5 is extremely urgent, 4 is high priority, and 1-3 is normal. Only respond with a number.\n\nMessage: "${message.text}"`,
          }],
        });
        
        const ratingText = response.choices[0]?.message?.content || '0';
        const rating = parseInt(ratingText.trim());
        
        if (rating === 5) {
          await snapshot.ref.update({
            priority: 'urgent',
          });
          console.log(`🚨 Message marked as URGENT (AI rating: ${rating}): ${message.id}`);
        } else if (rating === 4) {
          await snapshot.ref.update({
            priority: 'high',
          });
          console.log(`⚠️ Message marked as HIGH priority (AI rating: ${rating}): ${message.id}`);
        } else {
          console.log(`ℹ️ Message rated as normal (AI rating: ${rating}): ${message.id}`);
        }
        
      } catch (error) {
        console.error('❌ AI priority detection failed:', error);
        // Fallback: mark as high if keywords detected
        await snapshot.ref.update({
          priority: 'high',
        });
      }
    }
  });

