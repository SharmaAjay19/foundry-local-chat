#!/usr/bin/env python3
"""
start-foundry.py – Downloads models and starts the Foundry Local embedded web
service on port 5764 (OpenAI-compatible REST API).

Replaces start-foundry.mjs to work around the known JS SDK segfault on Linux
(https://github.com/microsoft/Foundry-Local/issues/626).

Usage: python3 start-foundry.py
"""

import signal
import sys
import time

from foundry_local_sdk import Configuration, FoundryLocalManager

MODEL_ALIASES = ["qwen2.5-0.5b", "qwen2.5-7b"]
SERVICE_URL = "http://127.0.0.1:5764"

def main():
    print("🔧 Initializing Foundry Local SDK...")
    config = Configuration(
        app_name="foundry_chat",
        web=Configuration.WebService(urls=SERVICE_URL),
    )
    FoundryLocalManager.initialize(config)
    manager = FoundryLocalManager.instance
    print("✓ SDK initialized\n")

    # Discover and download execution providers
    eps = manager.discover_eps()
    if eps:
        print("📦 Available execution providers:")
        max_len = max(len(ep.name) for ep in eps)
        for ep in eps:
            print(f"   {ep.name:<{max_len}}  registered: {ep.is_registered}")

        print("\n⬇  Downloading execution providers...")
        manager.download_and_register_eps(
            lambda name, pct: print(f"\r   {name:<{max_len}}  {pct:5.1f}%", end="", flush=True)
        )
        print("\n✓ Execution providers ready\n")
    else:
        print("ℹ  No additional execution providers to download\n")

    # Download and load models
    models = []
    for alias in MODEL_ALIASES:
        print(f"📥 Getting model: {alias}...")
        model = manager.catalog.get_model(alias)

        if not model.is_cached:
            print(f"⬇  Downloading {alias} (first run only)...")
            model.download(lambda pct: print(f"\r   Downloading... {pct:.1f}%", end="", flush=True))
            print(f"\n✓ {alias} downloaded\n")
        else:
            print(f"✓ {alias} already cached\n")

        print(f"🔄 Loading {alias} into memory...")
        model.load()
        print(f"✓ {alias} loaded\n")
        models.append(model)

    # Start embedded web service
    print(f"🚀 Starting Foundry Local web service on {SERVICE_URL}...")
    manager.start_web_service()
    print("✓ Web service running\n")

    print("═══════════════════════════════════════════════════")
    print(f"  Foundry Local API:  {SERVICE_URL}")
    print(f"  Models:             {', '.join(MODEL_ALIASES)}")
    print(f"  Endpoints:")
    print(f"    GET  {SERVICE_URL}/v1/models")
    print(f"    POST {SERVICE_URL}/v1/chat/completions")
    print("═══════════════════════════════════════════════════")
    print("\nFoundry Local is running. Press Ctrl+C to stop.\n")

    def shutdown(signum, frame):
        print("\n🛑 Shutting down...")
        try:
            for m in models:
                m.unload()
            manager.stop_web_service()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Block indefinitely
    while True:
        time.sleep(60)

if __name__ == "__main__":
    main()
