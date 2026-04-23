#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Foundry Chat – Ubuntu VM Setup Script
# Sets up everything needed to run the local Foundry service
# with the qwen2.5-0.5b and qwen2.5-7b models and the agentic chat interface.
#
# Tested on: Ubuntu 22.04 / 24.04 x64
# Usage:     chmod +x scripts/linux/setup-ubuntu.sh && ./scripts/linux/setup-ubuntu.sh [--stack node|python]
#
# --stack node    Install JS SDK for Foundry Local service
# --stack python  Install Python SDK for Foundry Local service (recommended on Linux)
#
# Default: python on Linux (JS SDK has a known segfault,
#          see https://github.com/microsoft/Foundry-Local/issues/626).
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
NODE_MAJOR=22
MODEL_ALIASES="qwen2.5-0.5b, qwen2.5-7b"
FOUNDRY_PORT=5764
CHAT_PORT=3000

# ── Parse arguments ─────────────────────────────────────────
STACK="python"

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
      echo "Usage: ./setup-ubuntu.sh [--stack node|python]" >&2
      exit 1
      ;;
  esac
done

if [[ "$STACK" == "node" ]]; then
  echo "⚠  Warning: --stack node on Linux may segfault due to a known JS SDK bug"
  echo "   (https://github.com/microsoft/Foundry-Local/issues/626)"
  echo "   Consider using --stack python instead."
  echo ""
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[  OK]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ── 1. System dependencies ──────────────────────────────────
info "Updating package lists..."
sudo apt-get update -qq

info "Installing system dependencies..."
sudo apt-get install -y -qq \
  curl \
  ca-certificates \
  gnupg \
  build-essential \
  > /dev/null 2>&1
ok "System dependencies installed"

# ── 2. Node.js ──────────────────────────────────────────────
if command -v node &>/dev/null; then
  CURRENT_NODE=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$CURRENT_NODE" -ge "$NODE_MAJOR" ]; then
    ok "Node.js $(node -v) already installed"
  else
    warn "Node.js $(node -v) found, but v${NODE_MAJOR}+ required. Installing..."
    INSTALL_NODE=true
  fi
else
  INSTALL_NODE=true
fi

if [ "${INSTALL_NODE:-false}" = true ]; then
  info "Installing Node.js ${NODE_MAJOR}.x..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq nodejs > /dev/null 2>&1
  ok "Node.js $(node -v) installed"
fi

# ── 3. npm dependencies ─────────────────────────────────────
info "Installing npm dependencies..."
cd "$PROJECT_DIR"

# Install the chat app dependencies (always needed for the Chat UI)
npm install --no-fund --no-audit 2>&1 | tail -1

if [[ "$STACK" == "node" ]]; then
  # Install foundry-local-sdk (cross-platform, works on Linux x64)
  npm install --save foundry-local-sdk --no-fund --no-audit 2>&1 | tail -1
fi
ok "npm dependencies installed"

# ── 4. Python dependencies (when --stack python) ────────────
if [[ "$STACK" == "python" ]]; then
  info "Setting up Python virtual environment..."
  sudo apt-get install -y -qq python3-venv python3-pip > /dev/null 2>&1
  python3 -m venv "$PROJECT_DIR/.venv"
  "$PROJECT_DIR/.venv/bin/pip" install --quiet foundry-local-sdk
  ok "Python SDK installed in .venv"
fi

# ── 5. Verify setup ─────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Stack:    ${STACK}"
echo "  Node.js:  $(node -v)"
echo "  npm:      $(npm -v)"
if [[ "$STACK" == "python" ]]; then
echo "  Python:   $("$PROJECT_DIR/.venv/bin/python3" --version)"
echo "  Venv:     $PROJECT_DIR/.venv"
fi
echo "  Models:   ${MODEL_ALIASES}"
echo "  Foundry:  http://127.0.0.1:${FOUNDRY_PORT}"
echo "  Chat UI:  http://localhost:${CHAT_PORT}"
echo ""
echo -e "${CYAN}To start everything:${NC}"
echo ""
if [[ "$STACK" == "python" ]]; then
echo "  # Option A: Run both together (recommended)"
echo "  ./scripts/linux/run.sh --stack python"
echo ""
echo "  # Option B: Run separately"
echo "  .venv/bin/python3 scripts/linux/start-foundry.py   # Terminal 1"
echo "  node server.js                                     # Terminal 2"
else
echo "  # Option A: Run both together"
echo "  ./scripts/linux/run.sh --stack node"
echo ""
echo "  # Option B: Run separately"
echo "  node scripts/linux/start-foundry.mjs   # Terminal 1"
echo "  node server.js                         # Terminal 2"
fi
echo ""
