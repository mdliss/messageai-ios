/**
 * SECURE Voice Memo Transcription using OpenAI Whisper
 *
 * SECURITY: API key stored in Cloud Functions environment variables
 * iOS app NEVER sees the API key - only calls this function
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as os from 'os';
import * as path from 'path';
import * as fs from 'fs';
import fetch from 'node-fetch';
import FormData from 'form-data';

interface Message {
  id: string;
  conversationId: string;
  type: 'text' | 'image' | 'voice';
  voiceURL?: string;
  transcription?: string;
}

/**
 * Transcribe voice memo when new voice message is created
 * Triggered automatically by Firestore
 */
export const transcribeVoiceMemo = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() as Message;
    const messageId = context.params.messageId;

    // Only process voice messages
    if (message.type !== 'voice' || !message.voiceURL) {
      return;
    }

    console.log(`🎤 New voice message ${messageId}, starting transcription...`);

    try {
      // SECURITY: Get API key from Firebase config (NEVER hardcode)
      const apiKey = functions.config().openai?.key;
      if (!apiKey) {
        console.error('❌ OpenAI API key not set in Firebase config');
        throw new Error('OpenAI API key not configured');
      }
      console.log('✅ OpenAI API key loaded from config');

      // Download audio file from Firebase Storage
      const bucket = admin.storage().bucket();
      const file = bucket.file(message.voiceURL);

      // Create temporary file path
      const tempFilePath = path.join(os.tmpdir(), `${messageId}.m4a`);

      // Download to temporary file
      await file.download({ destination: tempFilePath });
      console.log(`✅ Downloaded audio file to ${tempFilePath}`);

      // Get file size
      const stats = fs.statSync(tempFilePath);
      console.log(`📊 Audio file size: ${(stats.size / 1024 / 1024).toFixed(2)} MB`);

      // Prepare form data for Whisper API
      const formData = new FormData();
      formData.append('file', fs.createReadStream(tempFilePath));
      formData.append('model', 'whisper-1');
      formData.append('response_format', 'json');

      // Call OpenAI Whisper API
      console.log('🔄 Calling OpenAI Whisper API...');
      const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Whisper API error: ${response.status} - ${errorText}`);
      }

      const result = await response.json() as { text: string };
      const transcription = result.text;

      console.log(`✅ Transcription successful: "${transcription.substring(0, 100)}..."`);

      // Update message with transcription
      await snapshot.ref.update({
        transcription: transcription,
      });

      console.log(`✅ Message ${messageId} updated with transcription`);

      // Clean up temporary file
      fs.unlinkSync(tempFilePath);
      console.log('🧹 Temporary file cleaned up');

      // Send notification to participants (optional)
      // You can add push notification logic here if needed

    } catch (error) {
      console.error('❌ Error transcribing voice memo:', error);

      // Update message to indicate transcription failed
      await snapshot.ref.update({
        transcription: '[Transcription failed]',
      });
    }
  });

/**
 * Manual transcription endpoint (for retry or on-demand transcription)
 * Can be called from iOS app via Cloud Functions
 */
export const retranscribeVoiceMemo = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { messageId, conversationId } = data;

  if (!messageId || !conversationId) {
    throw new functions.https.HttpsError('invalid-argument', 'messageId and conversationId required');
  }

  try {
    const messageRef = admin.firestore()
      .collection(`conversations/${conversationId}/messages`)
      .doc(messageId);

    const messageDoc = await messageRef.get();
    if (!messageDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Message not found');
    }

    const message = messageDoc.data() as Message;

    if (message.type !== 'voice' || !message.voiceURL) {
      throw new functions.https.HttpsError('invalid-argument', 'Message is not a voice message');
    }

    // Same transcription logic as onCreate
    const apiKey = functions.config().openai?.key;
    if (!apiKey) {
      throw new functions.https.HttpsError('internal', 'OpenAI API key not configured');
    }
    console.log('✅ OpenAI API key loaded from config');

    const bucket = admin.storage().bucket();
    const file = bucket.file(message.voiceURL);
    const tempFilePath = path.join(os.tmpdir(), `${messageId}.m4a`);

    await file.download({ destination: tempFilePath });

    const formData = new FormData();
    formData.append('file', fs.createReadStream(tempFilePath));
    formData.append('model', 'whisper-1');
    formData.append('response_format', 'json');

    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
      body: formData,
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new functions.https.HttpsError('internal', `Whisper API error: ${errorText}`);
    }

    const result = await response.json() as { text: string };

    await messageRef.update({
      transcription: result.text,
    });

    fs.unlinkSync(tempFilePath);

    return {
      success: true,
      transcription: result.text,
    };

  } catch (error) {
    console.error('❌ Error in retranscribeVoiceMemo:', error);
    throw new functions.https.HttpsError('internal', 'Transcription failed');
  }
});
