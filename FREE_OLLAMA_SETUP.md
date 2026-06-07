# Free Ollama Setup with Ngrok

## How to Keep Ollama Free

Run Ollama on your Mac and expose it to the internet using **ngrok** (free tier).

### What You Get
- ✅ Free Ollama (runs on your Mac)
- ✅ Free ngrok tunnel (expose localhost to internet)
- ✅ Frontend on Vercel (free)
- ✅ Database on Convex (free)
- **Total cost: $0**

### Trade-offs
- ⚠️ Your Mac needs to be running for AI features to work
- ⚠️ Ngrok free tier has some limits (but plenty for personal use)
- ⚠️ URL changes each time you restart ngrok (can upgrade to static URL for $8/month)

---

## Setup Instructions

### Step 1: Install Ngrok (1 minute)

```bash
# Install via homebrew
brew install ngrok/ngrok/ngrok

# Sign up for free account (get auth token)
# Visit: https://dashboard.ngrok.com/signup
ngrok config add-authtoken YOUR_TOKEN_HERE
```

### Step 2: Expose Ollama (30 seconds)

```bash
# Ollama runs on port 11434
ngrok http 11434
```

You'll see output like:
```
Forwarding  https://abc123.ngrok.app -> http://localhost:11434
```

Copy that `https://abc123.ngrok.app` URL.

### Step 3: Set Environment Variable

Add to your Vercel project:

```bash
# In Vercel dashboard or CLI
OLLAMA_URL=https://abc123.ngrok.app
```

Or for local development:

```bash
# .env.local
OLLAMA_URL=https://abc123.ngrok.app/api/generate
```

### Step 4: Update API Routes

Your existing Ollama code already checks `process.env.OLLAMA_URL`, so it will automatically use the ngrok URL when deployed!

---

## Alternative: Persistent Ngrok (Optional)

If you want the same URL every time:

### Option A: Static Domain ($8/month)
- Get a permanent ngrok domain
- No need to update env vars

### Option B: Ngrok Agent Service (Free)
Create a config file to auto-start:

```yaml
# ~/.config/ngrok/ngrok.yml
version: "2"
authtoken: YOUR_TOKEN
tunnels:
  ollama:
    proto: http
    addr: 11434
```

Start with:
```bash
ngrok start ollama
```

---

## Production Setup (When Your Mac is Off)

### Fallback Strategy

Update your API routes to gracefully fall back:

```typescript
// src/lib/ollama-client.ts
export async function callOllama(prompt: string) {
  const ollamaUrl = process.env.OLLAMA_URL || 'http://localhost:11434/api/generate';
  
  try {
    const response = await fetch(ollamaUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        model: 'gemma4', 
        prompt,
        stream: false 
      }),
      signal: AbortSignal.timeout(30000), // 30s timeout
    });
    
    if (!response.ok) throw new Error('Ollama unavailable');
    
    return await response.json();
  } catch (error) {
    // Fallback: Return a friendly message
    console.warn('Ollama unavailable:', error);
    return {
      response: "AI temporarily unavailable. Please try again later.",
    };
  }
}
```

### Advanced: Auto-Wake Your Mac

Use **Shortcuts.app** + **SSH** to wake your Mac:
1. Set up Wake-on-LAN
2. Create a Vercel serverless function that triggers wake
3. Wait for Mac to start, then retry Ollama

---

## Recommended Workflow

### During Development
```bash
# Terminal 1: Run Ollama locally
ollama serve

# Terminal 2: Run Next.js
npm run dev

# No ngrok needed for local dev
```

### For Production (Deploy to Vercel)
```bash
# Terminal 1: Start ngrok
ngrok http 11434

# Copy the https URL

# Terminal 2: Deploy to Vercel with ngrok URL
vercel --build-env OLLAMA_URL=https://abc123.ngrok.app/api/generate
```

---

## Keeping Ngrok Running

### Option 1: Terminal Session
Just keep the terminal open

### Option 2: Background Process
```bash
# Start in background
ngrok http 11434 > /dev/null &

# Check it's running
ps aux | grep ngrok

# Kill when done
pkill ngrok
```

### Option 3: LaunchAgent (Auto-start on login)
Create `~/Library/LaunchAgents/com.ngrok.ollama.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ngrok.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ngrok</string>
        <string>http</string>
        <string>11434</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.ngrok.ollama.plist
```

---

## Cost Comparison

| Solution | Cost | Mac Requirement | Static URL |
|----------|------|-----------------|------------|
| **Ngrok Free** | $0 | Must be running | Changes |
| Ngrok Pro | $8/month | Must be running | ✅ Static |
| Railway | $5/month | ❌ No | ✅ Static |
| OpenAI | $1-5/month usage | ❌ No | ✅ N/A |

---

## Next Steps

1. Install ngrok
2. Start ngrok tunnel
3. Copy the URL
4. Set `OLLAMA_URL` in Vercel
5. Deploy!

Your app will be live with free Ollama! 🎉
