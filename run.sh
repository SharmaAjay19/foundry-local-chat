#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# run.sh – Start both Foundry Local service and Chat UI
# Usage: ./run.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cleanup() {
  echo ""
  echo "🛑 Shutting down..."
  kill "$FOUNDRY_PID" 2>/dev/null || true
  kill "$CHAT_PID" 2>/dev/null || true
  wait "$FOUNDRY_PID" 2>/dev/null || true
  wait "$CHAT_PID" 2>/dev/null || true
  echo "✓ Stopped"
}
trap cleanup EXIT INT TERM

# Start Foundry Local service in background
echo "🔧 Starting Foundry Local service..."
node start-foundry.mjs &
FOUNDRY_PID=$!

# Wait for the Foundry service to be ready
echo "⏳ Waiting for Foundry Local API on port 5764..."
for i in $(seq 1 120); do
  if curl -sf http://127.0.0.1:5764/v1/models > /dev/null 2>&1; then
    echo "✓ Foundry Local is ready"
    break
  fi
  if ! kill -0 "$FOUNDRY_PID" 2>/dev/null; then
    echo "✗ Foundry Local process died"
    exit 1
  fi
  sleep 2
done

# Check if we timed out
if ! curl -sf http://127.0.0.1:5764/v1/models > /dev/null 2>&1; then
  echo "✗ Timed out waiting for Foundry Local"
  exit 1
fi

# Start chat server
echo "🌐 Starting Chat UI..."
node server.js &
CHAT_PID=$!

echo ""
echo "════════════════════════════════════════════════════"
echo "  Foundry Chat is running!"
echo "  Chat UI:    http://localhost:3000"
echo "  Foundry:    http://127.0.0.1:5764"
echo "  Press Ctrl+C to stop both services"
echo "════════════════════════════════════════════════════"
echo ""

# Wait for either process to exit
wait -n "$FOUNDRY_PID" "$CHAT_PID" 2>/dev/null || true
