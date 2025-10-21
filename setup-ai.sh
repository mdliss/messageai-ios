#!/bin/bash

# AI Features Setup Script for MessageAI
# This script helps you deploy the OpenAI-powered AI features

set -e

echo "🤖 MessageAI - AI Features Setup"
echo "================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "   Install with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo "🔑 Please login to Firebase..."
    firebase login
fi

echo "✅ Firebase authenticated"

# Install dependencies
echo ""
echo "📦 Installing OpenAI SDK..."
cd functions
npm install

# Build functions
echo ""
echo "🔨 Building TypeScript functions..."
npm run build

echo ""
echo "✅ Functions built successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  NEXT STEPS - DO THESE MANUALLY:"
echo ""
echo "1️⃣  Set your OpenAI API key:"
echo "    firebase functions:config:set openai.key=\"sk-YOUR_OPENAI_KEY\""
echo ""
echo "2️⃣  Deploy functions to Firebase:"
echo "    firebase deploy --only functions"
echo ""
echo "3️⃣  Verify in Firebase Console:"
echo "    - Go to Firebase Console → Functions"
echo "    - You should see 5 functions deployed"
echo ""
echo "4️⃣  Test in app:"
echo "    - Open conversation"
echo "    - Tap sparkles icon → 'summarize'"
echo "    - AI summary appears in ~2-3 seconds"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Need help? Check AI_SETUP_GUIDE.md for full instructions"
echo ""

