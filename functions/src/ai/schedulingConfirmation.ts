/**
 * Confirm meeting time selection and post acknowledgment
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface Message {
  id: string;
  senderId: string;
  senderName: string;
  text: string;
  type: 'text' | 'image';
}

/**
 * Detect when user selects a meeting time option and confirm
 */
export const confirmSchedulingSelection = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB',
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
    
    // Skip if message is from AI assistant
    if (message.senderId === 'ai_assistant') {
      return;
    }
    
    const text = message.text.toLowerCase();
    
    // Pattern matching for option selection
    const optionPattern = /option\s*[123]/i;
    const agreementPatterns = ['works for me', 'that works', 'sounds good', "i'll take"];
    
    const hasOptionSelection = optionPattern.test(text);
    const hasAgreement = agreementPatterns.some(pattern => text.includes(pattern));
    
    if (!hasOptionSelection && !hasAgreement) {
      return;
    }
    
    console.log(`📅 Meeting time selection detected: ${message.id}`);
    
    try {
      // Fetch recent messages to find scheduling assistant message
      const messagesRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', 'desc')
        .limit(10);
      
      const messagesSnapshot = await messagesRef.get();
      const recentMessages = messagesSnapshot.docs.map(doc => doc.data() as Message);
      
      // Look for scheduling assistant message
      const schedulingMessage = recentMessages.find(msg => 
        msg.senderId === 'ai_assistant' && 
        msg.text.includes('scheduling assistant') &&
        msg.text.includes('option')
      );
      
      if (!schedulingMessage) {
        console.log('ℹ️ No scheduling assistant message found in recent history');
        return;
      }
      
      // Check if there's an active poll for this conversation
      const pollsRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('insights')
        .where('type', '==', 'decision')
        .where('dismissed', '==', false);
      
      const pollsSnapshot = await pollsRef.get();
      const activePoll = pollsSnapshot.docs.find(doc => {
        const data = doc.data();
        return data.metadata?.isPoll === true;
      });
      
      // Extract the selected option from user's message
      let selectedOption = 'your chosen time';
      let optionIndex = -1;
      const optionMatch = text.match(/option\s*([123])/i);
      
      if (optionMatch) {
        optionIndex = parseInt(optionMatch[1]) - 1;
        const optionNumber = optionMatch[1];
        // Extract the specific time from scheduling message
        const optionLines = schedulingMessage.text.split('\n');
        const selectedLine = optionLines.find(line => 
          line.toLowerCase().includes(`option ${optionNumber}`)
        );
        
        if (selectedLine) {
          // Extract just the time portion (after the colon)
          const timePart = selectedLine.split(':').slice(1).join(':').trim();
          selectedOption = timePart || selectedOption;
        }
      }
      
      // If there's an active poll, update vote instead of confirming
      if (activePoll && optionIndex >= 0) {
        console.log(`📊 Updating vote in poll ${activePoll.id} for user ${message.senderId}`);
        
        await activePoll.ref.update({
          [`metadata.votes.${message.senderId}`]: `option_${optionIndex + 1}`
        });
        
        // Check if all participants have voted
        const conversationRef = admin.firestore()
          .collection('conversations')
          .doc(conversationId);
        
        const conversationDoc = await conversationRef.get();
        const conversationData = conversationDoc.data();
        const participantIds = conversationData?.participantIds as string[] || [];
        
        // Get updated poll data
        const updatedPollDoc = await activePoll.ref.get();
        const updatedPollData = updatedPollDoc.data();
        const votes = updatedPollData?.metadata?.votes || {};
        const voteCount = Object.keys(votes).length;
        
        console.log(`📊 Poll status: ${voteCount}/${participantIds.length} votes`);
        
        // Only finalize if all participants have voted
        if (voteCount >= participantIds.length) {
          // Count votes for each option
          const voteCounts: {[key: string]: number} = {};
          Object.values(votes).forEach((vote: any) => {
            voteCounts[vote] = (voteCounts[vote] || 0) + 1;
          });
          
          // Find winning option
          let maxVotes = 0;
          let winningOption = 'option_1';
          Object.entries(voteCounts).forEach(([option, count]) => {
            if (count > maxVotes) {
              maxVotes = count;
              winningOption = option;
            }
          });
          
          // Extract winning time from poll
          const timeOptions = updatedPollData?.metadata?.timeOptions || [];
          const winningIndex = parseInt(winningOption.split('_')[1]) - 1;
          const winningTime = timeOptions[winningIndex] || selectedOption;
          
          // Post final decision message
          const finalMessageRef = admin.firestore()
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc();
          
          const finalMessage = {
            id: finalMessageRef.id,
            conversationId: conversationId,
            senderId: 'ai_assistant',
            senderName: 'ai assistant',
            senderPhotoURL: null,
            type: 'text',
            text: `🎉 everyone has voted! the meeting is scheduled for:\n\n${winningTime}\n\n(${maxVotes} of ${participantIds.length} votes)`,
            imageURL: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'sent',
            deliveredTo: [],
            readBy: [],
            localId: null,
            isSynced: true,
            priority: false,
          };
          
          await finalMessageRef.set(finalMessage);
          
          // Mark poll as completed (dismissed)
          await activePoll.ref.update({
            dismissed: true
          });
          
          console.log(`✅ Poll completed! Winning option: ${winningOption} with ${maxVotes} votes`);
        } else {
          // Acknowledge vote but don't finalize yet
          const confirmationRef = admin.firestore()
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc();
          
          const confirmationMessage = {
            id: confirmationRef.id,
            conversationId: conversationId,
            senderId: 'ai_assistant',
            senderName: 'ai assistant',
            senderPhotoURL: null,
            type: 'text',
            text: `✅ vote recorded for ${selectedOption}! waiting for ${participantIds.length - voteCount} more ${participantIds.length - voteCount === 1 ? 'person' : 'people'} to vote.`,
            imageURL: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'sent',
            deliveredTo: [],
            readBy: [],
            localId: null,
            isSynced: true,
            priority: false,
          };
          
          await confirmationRef.set(confirmationMessage);
          console.log(`📊 Vote acknowledged. Waiting for more votes: ${voteCount}/${participantIds.length}`);
        }
        
        return;
      }
      
      // No active poll - just post simple confirmation (for backward compatibility)
      const confirmationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();
      
      const confirmationMessage = {
        id: confirmationRef.id,
        conversationId: conversationId,
        senderId: 'ai_assistant',
        senderName: 'ai assistant',
        senderPhotoURL: null,
        type: 'text',
        text: `✅ great choice! i've noted that the meeting is scheduled for ${selectedOption}. this has been logged in your decisions tab for easy reference.`,
        imageURL: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'sent',
        deliveredTo: [],
        readBy: [],
        localId: null,
        isSynced: true,
        priority: false,
      };
      
      await confirmationRef.set(confirmationMessage);
      
      console.log(`✅ Meeting time confirmation sent for ${selectedOption}`);
      
    } catch (error) {
      console.error('❌ Scheduling confirmation failed:', error);
    }
  });

