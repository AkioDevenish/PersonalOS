#!/bin/bash

# Start Ollama Tunnel with Ngrok
# This exposes your local Ollama to the internet for FREE

echo "🚀 Starting Ollama Tunnel"
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok is not installed"
    echo "Install with: brew install ngrok/ngrok/ngrok"
    exit 1
fi

# Check if ngrok is configured
if [ ! -f ~/.ngrok2/ngrok.yml ]; then
    echo "⚠️  ngrok is not configured"
    echo ""
    echo "1. Sign up for free at: https://dashboard.ngrok.com/signup"
    echo "2. Get your authtoken"
    echo "3. Run: ngrok config add-authtoken YOUR_TOKEN"
    echo ""
    exit 1
fi

# Check if Ollama is running
if ! curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "⚠️  Ollama is not running on port 11434"
    echo "Start it with: ollama serve"
    echo ""
    read -p "Start ngrok anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Starting ngrok tunnel on port 11434"
echo ""
echo "Your Ollama will be accessible at:"
echo "https://XXXXXXXX.ngrok.app"
echo ""
echo "⚠️  Copy the URL and set it in Vercel:"
echo "   OLLAMA_URL=https://YOUR-URL.ngrok.app/api/generate"
echo ""
echo "Press Ctrl+C to stop the tunnel"
echo ""

# Start ngrok
ngrok http 11434
