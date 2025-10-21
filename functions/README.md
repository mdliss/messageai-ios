# MessageAI Cloud Functions

Firebase Cloud Functions for MessageAI app.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure Anthropic API key:
```bash
firebase functions:config:set anthropic.key="YOUR_API_KEY_HERE"
```

3. Build TypeScript:
```bash
npm run build
```

4. Deploy all functions:
```bash
npm run deploy
```

Or deploy specific function:
```bash
firebase deploy --only functions:sendMessageNotification
```

## Functions

### Notifications
- **sendMessageNotification** - Trigger: onCreate message, sends push to recipients

### AI Features
- **summarizeConversation** - HTTPS callable, returns 3-bullet summary
- **extractActionItems** - HTTPS callable, extracts tasks with owners
- **detectPriority** - Trigger: onCreate message, flags urgent messages
- **detectDecision** - Trigger: onCreate message, logs team decisions
- **detectProactiveSuggestions** - Trigger: onCreate message, offers scheduling help

## Testing

Run emulator:
```bash
npm run serve
```

View logs:
```bash
npm run logs
```

## Environment Variables

Set via Firebase CLI:
```bash
firebase functions:config:set anthropic.key="sk-..."
```

View current config:
```bash
firebase functions:config:get
```

