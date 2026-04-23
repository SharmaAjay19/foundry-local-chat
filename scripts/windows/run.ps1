# ─────────────────────────────────────────────────────────────
# run.ps1 – Start both Foundry Local service and Chat UI
#
# Uses the Foundry CLI to load models and then starts the
# Node.js chat server. Press Ctrl+C to stop both.
#
# Usage: .\scripts\windows\run.ps1
# ─────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = (Resolve-Path "$ScriptDir\..\..").Path

Push-Location $ProjectDir

$FoundryJob = $null
$ChatJob = $null

function Cleanup {
    Write-Host ""
    Write-Host "Shutting down..." -ForegroundColor Yellow
    if ($script:ChatJob -and $script:ChatJob.State -eq 'Running') {
        Stop-Job $script:ChatJob -ErrorAction SilentlyContinue
        Remove-Job $script:ChatJob -Force -ErrorAction SilentlyContinue
    }
    # Unload models via CLI (best-effort)
    try { foundry model unload qwen2.5-0.5b 2>$null } catch {}
    try { foundry model unload qwen2.5-7b 2>$null } catch {}
    Pop-Location
    Write-Host "Stopped" -ForegroundColor Green
}

# Register cleanup on Ctrl+C
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } -ErrorAction SilentlyContinue

try {
    # ── Load models via Foundry CLI ─────────────────────────
    $models = @("qwen2.5-0.5b", "qwen2.5-7b")

    foreach ($model in $models) {
        Write-Host "Loading model: $model..." -ForegroundColor Cyan
        foundry model load $model
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to load $model. Is Foundry Local installed?" -ForegroundColor Red
            Write-Host "Install: winget install Microsoft.FoundryLocal" -ForegroundColor Yellow
            exit 1
        }
        Write-Host "  $model loaded" -ForegroundColor Green
    }

    # ── Wait for Foundry API ────────────────────────────────
    Write-Host "Waiting for Foundry Local API on port 5764..." -ForegroundColor Cyan
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:5764/v1/models" -TimeoutSec 2 -ErrorAction Stop
            $ready = $true
            break
        } catch {
            Start-Sleep -Seconds 2
        }
    }

    if (-not $ready) {
        Write-Host "Timed out waiting for Foundry Local API" -ForegroundColor Red
        exit 1
    }
    Write-Host "Foundry Local is ready" -ForegroundColor Green

    # ── Start chat server ───────────────────────────────────
    Write-Host "Starting Chat UI..." -ForegroundColor Cyan
    $ChatJob = Start-Job -ScriptBlock {
        param($dir)
        Set-Location $dir
        node server.js 2>&1
    } -ArgumentList $ProjectDir
    $script:ChatJob = $ChatJob

    # Wait a moment for the server to start
    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Foundry Chat is running!" -ForegroundColor Green
    Write-Host "  Chat UI:    http://localhost:3000" -ForegroundColor White
    Write-Host "  Foundry:    http://127.0.0.1:5764" -ForegroundColor White
    Write-Host "  Press Ctrl+C to stop" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""

    # Stream chat server output and keep alive
    while ($ChatJob.State -eq 'Running') {
        Receive-Job $ChatJob -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # If we get here, the chat server exited
    Receive-Job $ChatJob -ErrorAction SilentlyContinue
    Write-Host "Chat server exited" -ForegroundColor Yellow

} finally {
    Cleanup
}
