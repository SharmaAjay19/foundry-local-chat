# ─────────────────────────────────────────────────────────────
# Foundry Chat – Windows Setup Script
# Sets up everything needed to run the local Foundry service
# with the qwen2.5-0.5b and qwen2.5-7b models and the agentic chat interface.
#
# Usage: .\scripts\windows\setup.ps1
# ─────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = (Resolve-Path "$ScriptDir\..\..").Path

# ── Colors ──────────────────────────────────────────────────
function Write-Info  ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok    ($msg) { Write-Host "[  OK]  $msg" -ForegroundColor Green }
function Write-Warn  ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail  ($msg) { Write-Host "[FAIL]  $msg" -ForegroundColor Red; exit 1 }

# ── 1. Check Node.js ────────────────────────────────────────
$RequiredNodeMajor = 20

$nodeVersion = $null
try { $nodeVersion = (node -v 2>$null) } catch {}

if ($nodeVersion) {
    $major = [int]($nodeVersion -replace '^v','').Split('.')[0]
    if ($major -ge $RequiredNodeMajor) {
        Write-Ok "Node.js $nodeVersion already installed"
    } else {
        Write-Fail "Node.js $nodeVersion found, but v${RequiredNodeMajor}+ required. Install from https://nodejs.org/"
    }
} else {
    Write-Fail "Node.js not found. Install from https://nodejs.org/ or run: winget install OpenJS.NodeJS.LTS"
}

# ── 2. Check Foundry Local CLI ──────────────────────────────
$foundryCmd = $null
try { $foundryCmd = Get-Command foundry -ErrorAction SilentlyContinue } catch {}

if ($foundryCmd) {
    Write-Ok "Foundry Local CLI found at $($foundryCmd.Source)"
} else {
    Write-Warn "Foundry Local CLI not found. Installing via winget..."
    try {
        winget install Microsoft.FoundryLocal --accept-source-agreements --accept-package-agreements
        Write-Ok "Foundry Local CLI installed"
    } catch {
        Write-Fail "Could not install Foundry Local. Install manually: winget install Microsoft.FoundryLocal"
    }
}

# ── 3. npm dependencies ─────────────────────────────────────
Write-Info "Installing npm dependencies..."
Push-Location $ProjectDir
try {
    npm install --no-fund --no-audit 2>&1 | Select-Object -Last 1
    Write-Ok "npm dependencies installed"
} finally {
    Pop-Location
}

# ── 4. Download models ──────────────────────────────────────
$models = @("qwen2.5-0.5b", "qwen2.5-7b")

foreach ($model in $models) {
    Write-Info "Downloading model: $model..."
    try {
        foundry model download $model
        Write-Ok "$model downloaded"
    } catch {
        Write-Warn "Could not download $model. You can download it later with: foundry model download $model"
    }
}

# ── 5. Summary ──────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Node.js:  $(node -v)"
Write-Host "  npm:      $(npm -v)"
Write-Host "  Models:   $($models -join ', ')"
Write-Host "  Foundry:  http://127.0.0.1:5764"
Write-Host "  Chat UI:  http://localhost:3000"
Write-Host ""
Write-Host "To start everything:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Option A: Run both together"
Write-Host "  .\scripts\windows\run.ps1"
Write-Host ""
Write-Host "  # Option B: Run separately"
Write-Host "  foundry model load qwen2.5-0.5b   # Terminal 1"
Write-Host "  foundry model load qwen2.5-7b"
Write-Host "  node server.js                     # Terminal 2"
Write-Host ""
