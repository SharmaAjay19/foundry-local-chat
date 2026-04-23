#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Foundry Chat – Ubuntu VM Setup Script
# Sets up everything needed to run the local Foundry service
# with the qwen2.5-0.5b model and the agentic chat interface.
#
# Tested on: Ubuntu 22.04 / 24.04 x64
# Usage:     chmod +x setup-ubuntu.sh && ./setup-ubuntu.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_MAJOR=22
MODEL_ALIAS="qwen2.5-0.5b"
FOUNDRY_PORT=5764
CHAT_PORT=3000

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
cd "$SCRIPT_DIR"

# Install the chat app dependencies
npm install --no-fund --no-audit 2>&1 | tail -1

# Install foundry-local-sdk (cross-platform, works on Linux x64)
npm install --save foundry-local-sdk --no-fund --no-audit 2>&1 | tail -1
ok "npm dependencies installed"

# ── 4. Verify setup ─────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  Node.js:  $(node -v)"
echo "  npm:      $(npm -v)"
echo "  Model:    ${MODEL_ALIAS}"
echo "  Foundry:  http://127.0.0.1:${FOUNDRY_PORT}"
echo "  Chat UI:  http://localhost:${CHAT_PORT}"
echo ""
echo -e "${CYAN}To start everything:${NC}"
echo ""
echo "  # Terminal 1: Start Foundry Local service (downloads model on first run)"
echo "  node start-foundry.mjs"
echo ""
echo "  # Terminal 2: Start the chat web app"
echo "  node server.js"
echo ""
echo "  # Or run both together:"
echo "  ./run.sh"
echo ""
