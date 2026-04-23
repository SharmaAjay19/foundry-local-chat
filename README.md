# Foundry Local Chat

An agentic chat interface powered by [Microsoft Foundry Local](https://github.com/microsoft/Foundry-Local). Everything runs on your machine — no cloud, no API keys, no per-token costs.

The LLM can call **tools** that you author as JavaScript functions directly in the browser. Tools are defined with a name, description, JSON Schema parameters, and a JS implementation that runs in a sandboxed VM on the server.

![screenshot](https://img.shields.io/badge/status-working-brightgreen)

## Features

- **Local AI** — Runs entirely on-device via Foundry Local + ONNX Runtime
- **Agentic tool calling** — OpenAI-style function calling with an automatic loop (up to 5 rounds)
- **In-browser tool authoring** — Create, edit, and delete tools from the sidebar without restarting
- **Sandboxed execution** — Tool code runs in a Node.js `vm` context with a 5-second timeout
- **Streaming responses** — Server-Sent Events for real-time token streaming
- **Tool call visualization** — Inline cards showing tool invocations and results in the chat

## Prerequisites

- **Node.js 20+**
- **Foundry Local** running on port `5764` with a model loaded

### Windows (quickest)

```bash
winget install Microsoft.FoundryLocal
foundry model run qwen2.5-0.5b
```

### macOS

```bash
brew install microsoft/foundrylocal/foundrylocal
foundry model run qwen2.5-0.5b
```

### Linux (Ubuntu)

Run the included setup script which installs Node.js and the `foundry-local-sdk` npm package (no separate CLI needed):

```bash
chmod +x setup-ubuntu.sh run.sh
./setup-ubuntu.sh
```

## Quick Start

```bash
# 1. Clone
git clone https://github.com/SharmaAjay19/foundry-local-chat.git
cd foundry-local-chat

# 2. Install dependencies
npm install

# 3. Make sure Foundry Local is running with a model loaded
#    (Windows/macOS: foundry model run qwen2.5-0.5b)

# 4. Start the chat server
npm start
```

Open **http://localhost:3000** in your browser.

### Linux — All-in-One

On Ubuntu, after running `setup-ubuntu.sh`, use the combined launcher:

```bash
./run.sh
```

This starts the Foundry Local service (downloads the model on first run) and the chat UI together.

## Project Structure

```
foundry-chat/
├── server.js           # Express server: tool registry, agentic loop, SSE streaming
├── start-foundry.mjs   # Starts Foundry Local via JS SDK (for Linux/cross-platform)
├── public/
│   └── index.html      # Chat UI with tool sidebar and tool-call visualization
├── setup-ubuntu.sh     # Ubuntu VM setup (Node.js + npm deps + foundry-local-sdk)
├── run.sh              # Launches Foundry service + chat server together
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
   OpenAI-compatible /v1/chat/completions
   ONNX Runtime (CPU / GPU / NPU)
```

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
