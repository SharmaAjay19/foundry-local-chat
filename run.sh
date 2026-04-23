#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# run.sh – Start both Foundry Local service and Chat UI
# Usage: ./run.sh [--stack node|python]
#
# --stack node    Use Node.js SDK (start-foundry.mjs)
# --stack python  Use Python SDK  (start-foundry.py)
#
# Default: python on Linux (JS SDK has a known segfault,
#          see https://github.com/microsoft/Foundry-Local/issues/626),
#          node on other platforms.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Parse arguments ─────────────────────────────────────────
if [[ "$(uname -s)" == "Linux" ]]; then
  STACK="python"
else
  STACK="node"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)
      STACK="${2:-}"
      if [[ "$STACK" != "node" && "$STACK" != "python" ]]; then
        echo "✗ Invalid --stack value: '$STACK'. Must be 'node' or 'python'." >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "✗ Unknown argument: $1" >&2
      echo "Usage: ./run.sh [--stack node|python]" >&2
      exit 1
      ;;
  esac
done

if [[ "$STACK" == "node" && "$(uname -s)" == "Linux" ]]; then
  echo "⚠  Warning: --stack node on Linux may segfault due to a known JS SDK bug"
  echo "   (https://github.com/microsoft/Foundry-Local/issues/626)"
  echo "   Consider using --stack python instead."
  echo ""
fi

# ── Cleanup ─────────────────────────────────────────────────
FOUNDRY_PID=""
CHAT_PID=""

cleanup() {
  echo ""
  echo "🛑 Shutting down..."
  [[ -n "$FOUNDRY_PID" ]] && kill "$FOUNDRY_PID" 2>/dev/null || true
  [[ -n "$CHAT_PID" ]]    && kill "$CHAT_PID" 2>/dev/null || true
  [[ -n "$FOUNDRY_PID" ]] && wait "$FOUNDRY_PID" 2>/dev/null || true
  [[ -n "$CHAT_PID" ]]    && wait "$CHAT_PID" 2>/dev/null || true
  echo "✓ Stopped"
}
trap cleanup EXIT INT TERM

# ── Start Foundry Local service ─────────────────────────────
echo "🔧 Starting Foundry Local service (stack: $STACK)..."
if [[ "$STACK" == "python" ]]; then
  VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python3"
  if [[ -x "$VENV_PYTHON" ]]; then
    "$VENV_PYTHON" start-foundry.py &
  else
    python3 start-foundry.py &
  fi
else
  node start-foundry.mjs &
fi
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
echo "  Stack:      $STACK"
echo "  Chat UI:    http://localhost:3000"
echo "  Foundry:    http://127.0.0.1:5764"
echo "  Press Ctrl+C to stop both services"
echo "════════════════════════════════════════════════════"
echo ""

# Wait for either process to exit
wait -n "$FOUNDRY_PID" "$CHAT_PID" 2>/dev/null || true
