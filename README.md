# Foundry Local Chat

An agentic chat interface powered by [Microsoft Foundry Local](https://github.com/microsoft/Foundry-Local). Everything runs on your machine — no cloud, no API keys, no per-token costs.

The LLM can call **tools** that you author as JavaScript functions directly in the browser. Tools are defined with a name, description, JSON Schema parameters, and a JS implementation that runs in a sandboxed VM on the server.

![screenshot](https://img.shields.io/badge/status-working-brightgreen)

## Features

- **Local AI** — Runs entirely on-device via Foundry Local + ONNX Runtime
- **Two models** — Ships with `qwen2.5-0.5b` (fast, lightweight) and `qwen2.5-7b` (better reasoning & tool creation)
- **Agentic tool calling** — OpenAI-style function calling with an automatic loop (up to 5 rounds)
- **In-browser tool authoring** — Create, edit, and delete tools from the sidebar without restarting
- **Dynamic tool creation** — The `tool_creator` meta-tool lets the LLM create new tools on the fly (works best with the 7B model)
- **Sandboxed execution** — Tool code runs in a Node.js `vm` context with a 5-second timeout
- **Streaming responses** — Server-Sent Events for real-time token streaming
- **Tool call visualization** — Inline cards showing tool invocations and results in the chat
- **Two Foundry stacks** — Node.js SDK (`start-foundry.mjs`) or Python SDK (`start-foundry.py`) for starting the Foundry service

## Prerequisites

- **Node.js 20+** (required for the chat server regardless of stack choice)
- **Foundry Local** — either via the CLI (Windows/macOS) or the SDK (Linux)

## Setup

### Windows

```bash
# Install Foundry Local CLI
winget install Microsoft.FoundryLocal

# Clone and install
git clone https://github.com/SharmaAjay19/foundry-local-chat.git
cd foundry-local-chat
npm install

# Download both models
foundry model download qwen2.5-0.5b
foundry model download qwen2.5-7b
```

### macOS

```bash
# Install Foundry Local CLI
brew install microsoft/foundrylocal/foundrylocal

# Clone and install
git clone https://github.com/SharmaAjay19/foundry-local-chat.git
cd foundry-local-chat
npm install

# Download both models
foundry model download qwen2.5-0.5b
foundry model download qwen2.5-7b
```

### Linux (Ubuntu)

The included setup script installs Node.js, the Foundry SDK, and all dependencies. Choose your preferred stack for running the Foundry service:

**Python stack (recommended on Linux):**

```bash
git clone https://github.com/SharmaAjay19/foundry-local-chat.git
cd foundry-local-chat
chmod +x setup-ubuntu.sh run.sh
./setup-ubuntu.sh --stack python
```

This creates a `.venv` virtualenv with the `foundry-local-sdk` Python package.

**Node.js stack:**

```bash
./setup-ubuntu.sh --stack node
```

> **Note:** The JS SDK has a [known segfault on Linux](https://github.com/microsoft/Foundry-Local/issues/626). The Python stack is recommended.

## Running

### Option A: All-in-One (Linux / macOS)

```bash
# Python stack (default on Linux)
./run.sh

# Node.js stack
./run.sh --stack node
```

This starts the Foundry service (downloads models on first run), waits for it to be ready, then starts the chat server. Press `Ctrl+C` to stop both.

### Option B: Run Services Separately

**Terminal 1 — Start Foundry Local service:**

Using the Python SDK:
```bash
# Linux (with venv)
.venv/bin/python3 start-foundry.py

# Windows/macOS (if Python SDK is installed globally)
python3 start-foundry.py
```

Using the Node.js SDK:
```bash
node start-foundry.mjs
```

Using the Foundry CLI (Windows/macOS only):
```bash
foundry model load qwen2.5-0.5b
foundry model load qwen2.5-7b
foundry service start
```

**Terminal 2 — Start the chat server:**

```bash
node server.js
# or
npm start
```

### Open the Chat UI

Navigate to **http://localhost:3000** in your browser. Select a model from the dropdown — use `qwen2.5-7b` for better tool creation and reasoning.

## Project Structure

```
foundry-chat/
├── server.js           # Express server: tool registry, agentic loop, SSE streaming
├── start-foundry.mjs   # Starts Foundry Local via Node.js SDK (downloads & loads both models)
├── start-foundry.py    # Starts Foundry Local via Python SDK (same, for Linux compatibility)
├── public/
│   └── index.html      # Chat UI with tool sidebar and tool-call visualization
├── setup-ubuntu.sh     # Ubuntu setup (--stack node|python)
├── run.sh              # Combined launcher (--stack node|python)
└── package.json
```

## Architecture

```
Browser (index.html)
   │  POST /api/chat (SSE)
   ▼
Express server (server.js)
   │  Agentic loop:
   │   1. Send messages + tool definitions to LLM
   │   2. If LLM returns tool_calls → execute in VM → feed results back → repeat
   │   3. Stream final text response as SSE tokens
   ▼
Foundry Local (port 5764)
   Started by start-foundry.mjs (Node) or start-foundry.py (Python)
   Models: qwen2.5-0.5b, qwen2.5-7b
   OpenAI-compatible /v1/chat/completions
   ONNX Runtime (CPU / GPU / NPU)
```

## Models

| Model | Parameters | CPU Size | Best For |
|-------|-----------|----------|----------|
| `qwen2.5-0.5b` | 0.5B | 0.80 GB | Fast responses, simple tool calls (calculator, etc.) |
| `qwen2.5-7b` | 7B | 6.16 GB | Complex reasoning, tool creation, code generation |

Both models are downloaded and loaded by the startup scripts. Select the model from the dropdown in the chat UI.

## Creating Tools

Click **+ New Tool** in the sidebar. Each tool needs:

| Field | Description |
|-------|-------------|
| **Name** | Lowercase identifier the LLM calls (e.g. `weather_lookup`) |
| **Description** | What the tool does — this is what the LLM reads to decide when to use it |
| **Parameters** | JSON Schema defining the arguments |
| **Code** | JavaScript function body. Access arguments via `args`. Return an object. |

Tools run in a sandboxed `vm` context with access to `Math`, `JSON`, `Date`, `parseInt`, `parseFloat`, and `String`/`Number`/`Boolean`/`Array`/`Object` constructors.

### Example: Calculator (pre-loaded)

```javascript
// args: { expression: string }
const expr = args.expression;
const result = Function('"use strict"; return (' + expr + ')')();
return { result: Number(result) };
```

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/models` | GET | List available Foundry Local models |
| `/api/tools` | GET | List all registered tools |
| `/api/tools/:name` | GET | Get a single tool |
| `/api/tools/:name` | PUT | Create or update a tool |
| `/api/tools/:name` | DELETE | Remove a tool |
| `/api/chat` | POST | Send a chat message (SSE response) |

## License

MIT
