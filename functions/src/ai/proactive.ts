/**
 * Proactive assistant for detecting scheduling needs using OpenAI GPT
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
}

/**
 * Detect scheduling needs and offer help
 */
export const detectProactiveSuggestions = functions
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
  })
  .firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const conversationId = context.params.conversationId;
    
    // Only check text messages
    if (message.type !== 'text') {
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for scheduling keywords
    const schedulingKeywords = [
      'when can',
      'what time',
      'schedule',
      'meeting',
      'available',
      'free time',
      'book',
      'calendar',
      'coordinate',
    ];
    
    const hasSchedulingKeyword = schedulingKeywords.some(keyword => 
      text.includes(keyword)
    );
    
    if (!hasSchedulingKeyword) {
      return;
    }
    
    console.log(`📅 Scheduling language detected in message: ${message.id}`);
    
    try {
      const apiKey = functions.config().openai?.key;
      
      if (!apiKey) {
        console.log('ℹ️ OpenAI API key not configured');
        return;
      }
      
      // Fetch recent messages for context
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(20);
      
      const messagesSnapshot = await messagesRef.get();
      const recentMessages = messagesSnapshot.docs
        .map(doc => doc.data() as Message)
        .reverse();
      
      const transcript = recentMessages.map(msg => 
        `${msg.senderName}: ${msg.text}`
      ).join('\n');
      
      // Call OpenAI to assess scheduling need
      const openai = new OpenAI({
        apiKey: apiKey,
      });
      
      // Get current day and time for better suggestions
      const now = new Date();
      const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });
      const currentHour = now.getHours();
      
      const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        max_tokens: 600,
        temperature: 0.7,
        messages: [{
          role: 'system',
          content: 'You are a proactive scheduling assistant for remote teams working across time zones. Analyze conversations to detect scheduling needs and suggest concrete meeting times that work globally. Never use hyphens. Be concise and actionable. Always provide times in multiple major time zones (EST, PST, GMT, IST) to help distributed teams.',
        }, {
          role: 'user',
          content: `Analyze this conversation for scheduling needs. Current context: ${dayOfWeek}, ${currentHour}:00.

If there is a clear need to coordinate schedules or set up a meeting:

1. Rate confidence (0-100) that they need scheduling help
2. Suggest 3 specific time options considering:
   • Avoid early mornings (before 9am) and late evenings (after 6pm) in all time zones when possible
   • Prefer Tuesday through Thursday for better attendance
   • Suggest times during typical overlap hours: 9am-11am PST / 12pm-2pm EST / 5pm-7pm GMT / 10:30pm-12:30am IST
   • Consider urgency mentioned in the conversation
   
3. Format as:

Confidence: [number]
Suggestion: [one sentence about helping coordinate schedules]
Times:
• option 1: [day] [time] EST / [time] PST / [time] GMT / [time] IST
• option 2: [day] [time] EST / [time] PST / [time] GMT / [time] IST  
• option 3: [day] [time] EST / [time] PST / [time] GMT / [time] IST

Examples of good suggestions:
• tomorrow 2pm EST / 11am PST / 7pm GMT / 12:30am IST (next day)
• thursday 10am EST / 7am PST / 3pm GMT / 8:30pm IST
• friday 1pm EST / 10am PST / 6pm GMT / 11:30pm IST

Conversation:
${transcript}`,
        }],
      });
      
      const analysisText = response.choices[0]?.message?.content || '';
      
      // Parse confidence
      const confidenceMatch = analysisText.match(/confidence:\s*(\d+)/i);
      const confidence = confidenceMatch ? parseInt(confidenceMatch[1]) : 0;
      
      // Extract suggested times
      const timesMatch = analysisText.match(/Times:\s*([\s\S]*?)(?:\n\n|$)/i);
      const suggestedTimes = timesMatch ? timesMatch[1].trim() : '';
      
      // Extract suggestion message
      const suggestionMatch = analysisText.match(/Suggestion:\s*([^\n]+)/i);
      const suggestionText = suggestionMatch ? suggestionMatch[1].trim() : 'Would you like help coordinating schedules?';
      
      if (confidence > 70) {
        // Create enhanced suggestion insight with time options
        const insightRef = admin.firestore()
          .collection('conversations')
          .doc(conversationId)
          .collection('insights')
          .doc();
        
        // Build suggestion content with times
        let content = suggestionText;
        if (suggestedTimes) {
          content += '\n\n' + suggestedTimes;
        }
        
        const insight = {
          id: insightRef.id,
          conversationId: conversationId,
          type: 'suggestion',
          content: content,
          metadata: {
            action: 'scheduling_help',
            confidence: confidence / 100,
            suggestedTimes: suggestedTimes || null,
            targetUserId: message.senderId,
          },
          messageIds: [message.id],
          triggeredBy: 'system',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          dismissed: false,
        };
        
        await insightRef.set(insight);
        
        console.log(`✅ Scheduling suggestion created (confidence: ${confidence}%)`);
        console.log(`   Times suggested: ${suggestedTimes || 'none'}`);
      } else {
        console.log(`ℹ️ Confidence too low for suggestion: ${confidence}%`);
      }
      
    } catch (error) {
      console.error('❌ Proactive detection failed:', error);
    }
  });

