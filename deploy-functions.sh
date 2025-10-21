#!/bin/bash

echo "🚀 Deploying MessageAI Cloud Functions"
echo ""

# Check if in functions directory
if [ ! -f "package.json" ]; then
    cd functions
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not installed"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if Anthropic API key is set
echo "📋 Checking Anthropic API key configuration..."
firebase functions:config:get anthropic.key > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "⚠️  Anthropic API key not configured"
    echo ""
    read -p "Enter your Anthropic API key: " api_key
    firebase functions:config:set anthropic.key="$api_key"
fi

# Build TypeScript
echo ""
echo "🔨 Building TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# Deploy functions
echo ""
echo "☁️  Deploying to Firebase..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "📬 Notifications should now work when messages are sent"
    echo "🤖 AI features are ready to use"
else
    echo ""
    echo "❌ Deployment failed"
    echo "Check the error messages above"
fi

