// ─────────────────────────────────────────────────────────────
// start-foundry.mjs
// Downloads the qwen2.5-0.5b model and starts the Foundry Local
// embedded web service on port 5764 (OpenAI-compatible REST API).
//
// Usage: node start-foundry.mjs
// ─────────────────────────────────────────────────────────────
import { FoundryLocalManager } from "foundry-local-sdk";

const MODEL_ALIAS = "qwen2.5-0.5b";
const SERVICE_URL = "http://127.0.0.1:5764";

console.log("🔧 Initializing Foundry Local SDK...");
const manager = FoundryLocalManager.create({
  appName: "foundry_chat",
  logLevel: "info",
  webServiceUrls: SERVICE_URL,
});
console.log("✓ SDK initialized\n");

// ── Discover and download execution providers ───────────────
const eps = manager.discoverEps();
if (eps.length > 0) {
  console.log("📦 Available execution providers:");
  const maxLen = Math.max(...eps.map((e) => e.name.length), 10);
  for (const ep of eps) {
    console.log(`   ${ep.name.padEnd(maxLen)}  registered: ${ep.isRegistered}`);
  }

  console.log("\n⬇  Downloading execution providers...");
  let currentEp = "";
  await manager.downloadAndRegisterEps((epName, percent) => {
    if (epName !== currentEp) {
      if (currentEp !== "") process.stdout.write("\n");
      currentEp = epName;
    }
    process.stdout.write(
      `\r   ${epName.padEnd(maxLen)}  ${percent.toFixed(1).padStart(5)}%`
    );
  });
  process.stdout.write("\n");
  console.log("✓ Execution providers ready\n");
} else {
  console.log("ℹ  No additional execution providers to download\n");
}

// ── Download model ──────────────────────────────────────────
console.log(`📥 Getting model: ${MODEL_ALIAS}...`);
const model = await manager.catalog.getModel(MODEL_ALIAS);

if (!model.isCached) {
  console.log(`⬇  Downloading ${MODEL_ALIAS} (first run only)...`);
  await model.download((progress) => {
    process.stdout.write(`\r   Downloading... ${progress.toFixed(1)}%`);
  });
  process.stdout.write("\n");
  console.log("✓ Model downloaded\n");
} else {
  console.log("✓ Model already cached\n");
}

// ── Load model ──────────────────────────────────────────────
console.log(`🔄 Loading ${MODEL_ALIAS} into memory...`);
await model.load();
console.log("✓ Model loaded\n");

// ── Start embedded web service ──────────────────────────────
console.log(`🚀 Starting Foundry Local web service on ${SERVICE_URL}...`);
manager.startWebService();
console.log("✓ Web service running\n");

console.log("═══════════════════════════════════════════════════");
console.log(`  Foundry Local API:  ${SERVICE_URL}`);
console.log(`  Model:              ${MODEL_ALIAS}`);
console.log(`  Endpoints:`);
console.log(`    GET  ${SERVICE_URL}/v1/models`);
console.log(`    POST ${SERVICE_URL}/v1/chat/completions`);
console.log("═══════════════════════════════════════════════════");
console.log("\nPress Ctrl+C to stop.\n");

// Keep process alive
process.on("SIGINT", () => {
  console.log("\n🛑 Shutting down...");
  try {
    model.unload();
    manager.stopWebService();
  } catch {}
  process.exit(0);
});

process.on("SIGTERM", () => {
  try {
    model.unload();
    manager.stopWebService();
  } catch {}
  process.exit(0);
});

// Block indefinitely
await new Promise(() => {});
