/**
 * MessageAI Cloud Functions
 * 
 * Main entry point for all Firebase Cloud Functions
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
admin.initializeApp();

// Export notification functions
// Temporarily commented out - using local notifications in Swift app instead
// export { sendMessageNotification } from './notifications/sendMessage';

// Export AI functions
export { summarizeConversation } from './ai/summarize';
export { extractActionItems } from './ai/actionItems';
export { detectPriority } from './ai/priority';
export { detectDecision } from './ai/decisions';
export { detectProactiveSuggestions } from './ai/proactive';
export { confirmSchedulingSelection } from './ai/schedulingConfirmation';
export { searchMessages } from './ai/search';
export { generateMessageEmbedding } from './ai/embeddings';
export { ragSearch } from './ai/ragSearch';

// Export Advanced AI features
export { generateResponseSuggestions } from './ai/responseSuggestions';
export { detectBlocker, onMessageCreatedCheckBlocker } from './ai/blockerDetection';
export { analyzeSentiment, onMessageCreatedAnalyzeSentiment, calculateSentimentAggregates } from './ai/sentiment';

console.log('✅ MessageAI Cloud Functions initialized');

