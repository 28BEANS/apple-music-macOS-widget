#!/bin/bash

# ==============================================================================
# Apple Music Widget+ Dev Environment Bootstrapper
# Starts the backend lyrics proxy and launches the Flutter macOS app.
# Cleanly terminates all child processes upon exit.
# ==============================================================================

# Ensure we clean up background processes on script exit or user interrupt
cleanup() {
  echo ""
  if [ ! -z "$BACKEND_PID" ]; then
    echo "🛑 Shutting down lyrics backend service (PID: $BACKEND_PID)..."
    kill "$BACKEND_PID" 2>/dev/null
  fi
  echo "✨ Workspace shut down successfully."
  exit 0
}

trap cleanup EXIT INT TERM

# Print dynamic premium startup banner
clear
echo "=================================================="
echo "🎵  Starting Apple Music Widget+ Workspace  🎵"
echo "=================================================="

# Check for .env file
if [ ! -f .env ]; then
  echo "⚠️  Warning: .env configuration file not found at workspace root!"
  echo "👉 Please copy .env.example to .env and configure your keys."
  exit 1
fi

# Load environment variables
source .env

if [ -z "$GENIUS_API_KEY" ] || [ "$GENIUS_API_KEY" = "your_genius_api_key_here" ]; then
  echo "⚠️  Warning: GENIUS_API_KEY is not configured in .env."
  echo "💡  Genius scraping fallback capability will be disabled."
fi

# Step 1: Initialize and Start Python Backend in virtual environment (venv)
echo "🚀 Initializing and starting lyrics backend service in .venv..."
cd backend/lyrics

if [ ! -d ".venv" ]; then
  echo "📦 Creating Python virtual environment (.venv)..."
  python3 -m venv .venv
  source .venv/bin/activate
  echo "📥 Installing dependencies from requirements.txt..."
  pip install --upgrade pip >/dev/null
  pip install -r requirements.txt >/dev/null
else
  source .venv/bin/activate
fi

# Run the backend in background
python main.py > /dev/null 2>&1 &
BACKEND_PID=$!
cd ../..

# Step 2: Validate backend health
echo "⏳ Waiting for backend to initialize..."
for i in {1..10}; do
  if curl -s http://localhost:8000/health | grep -q "ok"; then
    echo "✅ Lyrics backend is healthy and responding."
    break
  fi
  if [ $i -eq 10 ]; then
    echo "❌ Error: Lyrics backend failed to start or respond."
    exit 1
  fi
  sleep 0.5
done

# Step 3: Run Flutter macOS application
echo "📱 Launching Flutter macOS application context..."
cd flutter_app
flutter run -d macos
cd ..
