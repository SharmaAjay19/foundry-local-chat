const express = require("express");
const path = require("path");
const vm = require("vm");

const app = express();
const PORT = process.env.PORT || 3000;
const FOUNDRY_BASE = "http://127.0.0.1:5764";
const MAX_TOOL_ROUNDS = 5;

app.use(express.json({ limit: "1mb" }));
app.use(express.static(path.join(__dirname, "public")));

// ── Tool Registry ──────────────────────────────────────────
const tools = new Map();

// Seed: calculator tool
tools.set("calculator", {
  name: "calculator",
  description:
    "Evaluate a mathematical expression and return the numeric result. Supports +, -, *, /, %, ** (power), Math functions like Math.sqrt(), Math.pow(), Math.PI etc.",
  parameters: {
    type: "object",
    properties: {
      expression: {
        type: "string",
        description:
          "The mathematical expression to evaluate, e.g. '2 + 2', '15 * 37', 'Math.sqrt(144)'",
      },
    },
    required: ["expression"],
  },
  code: `// args: { expression: string }
const expr = args.expression;
const result = Function('"use strict"; return (' + expr + ')')();
return { result: Number(result) };`,
});

// ── Tool CRUD API ──────────────────────────────────────────
app.get("/api/tools", (_req, res) => res.json([...tools.values()]));

app.get("/api/tools/:name", (req, res) => {
  const t = tools.get(req.params.name);
  t ? res.json(t) : res.status(404).json({ error: "Tool not found" });
});

app.put("/api/tools/:name", (req, res) => {
  const { description, parameters, code } = req.body;
  const name = req.params.name;
  if (!name || !description || !parameters || !code) {
    return res.status(400).json({ error: "name, description, parameters, and code required" });
  }
  tools.set(name, { name, description, parameters, code });
  res.json(tools.get(name));
});

app.delete("/api/tools/:name", (req, res) => {
  tools.delete(req.params.name)
    ? res.json({ ok: true })
    : res.status(404).json({ error: "Tool not found" });
});

// ── Tool Executor (sandboxed) ──────────────────────────────
function executeTool(toolName, argsObj) {
  const tool = tools.get(toolName);
  if (!tool) return { error: `Unknown tool: ${toolName}` };
  try {
    const sandbox = {
      args: argsObj,
      Math, Number, String, Boolean, Array, Object, JSON, Date,
      parseInt, parseFloat, isNaN, isFinite,
      console: { log: () => {} },
    };
    const result = vm.runInNewContext(
      `(function() {\n${tool.code}\n})()`,
      sandbox,
      { timeout: 5000, filename: `tool:${toolName}` },
    );
    return result ?? { result: "No return value" };
  } catch (err) {
    return { error: `Tool execution failed: ${err.message}` };
  }
}

// ── OpenAI tools format ────────────────────────────────────
function getOpenAITools() {
  return [...tools.values()].map((t) => ({
    type: "function",
    function: { name: t.name, description: t.description, parameters: t.parameters },
  }));
}

// ── Models endpoint ────────────────────────────────────────
app.get("/api/models", async (_req, res) => {
  try {
    const upstream = await fetch(`${FOUNDRY_BASE}/v1/models`);
    res.json(await upstream.json());
  } catch (err) {
    res.status(502).json({ error: `Cannot reach Foundry Local: ${err.message}` });
  }
});

// ── Agentic Chat (SSE) ────────────────────────────────────
// Events: tool_call, tool_result, token, done, error
app.post("/api/chat", async (req, res) => {
  const { model, messages, temperature = 0.7, max_tokens = 2048 } = req.body;
  if (!model || !Array.isArray(messages)) {
    return res.status(400).json({ error: "model and messages are required" });
  }

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();

  const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);

  try {
    const openaiTools = getOpenAITools();
    const conv = [...messages];
    let rounds = 0;

    while (rounds < MAX_TOOL_ROUNDS) {
      rounds++;

      // Non-streaming call to detect tool_calls
      const llmRes = await fetch(`${FOUNDRY_BASE}/v1/chat/completions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model, messages: conv, temperature, max_tokens, stream: false,
          ...(openaiTools.length > 0 && { tools: openaiTools, tool_choice: "auto" }),
        }),
      });

      if (!llmRes.ok) {
        send("error", { message: `Foundry Local ${llmRes.status}: ${await llmRes.text()}` });
        return res.end();
      }

      const choice = (await llmRes.json()).choices?.[0];
      if (!choice) { send("error", { message: "No response from model" }); return res.end(); }

      const msg = choice.message || choice.delta;
      const toolCalls = msg?.tool_calls?.filter((tc) => tc.function);

      // No tool calls → stream final text response
      if (!toolCalls || toolCalls.length === 0) {
        const streamRes = await fetch(`${FOUNDRY_BASE}/v1/chat/completions`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ model, messages: conv, temperature, max_tokens, stream: true }),
        });
        const reader = streamRes.body.getReader();
        const dec = new TextDecoder();
        let buf = "";
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buf += dec.decode(value, { stream: true });
          const lines = buf.split("\n");
          buf = lines.pop() || "";
          for (const line of lines) {
            if (!line.startsWith("data: ")) continue;
            const p = line.slice(6).trim();
            if (p === "[DONE]") break;
            if (!p) continue;
            try {
              const c = JSON.parse(p).choices?.[0]?.delta?.content;
              if (c) send("token", { content: c });
            } catch {}
          }
        }
        send("done", {});
        return res.end();
      }

      // ── Execute tool calls ─────────────────────────
      conv.push({
        role: "assistant", content: msg.content || null,
        tool_calls: toolCalls.map((tc) => ({
          id: tc.id, type: "function",
          function: { name: tc.function.name, arguments: tc.function.arguments },
        })),
      });

      for (const tc of toolCalls) {
        let fnArgs = {};
        try { fnArgs = JSON.parse(tc.function.arguments); } catch {}
        send("tool_call", { id: tc.id, name: tc.function.name, arguments: fnArgs });
        const result = executeTool(tc.function.name, fnArgs);
        send("tool_result", { id: tc.id, name: tc.function.name, result });
        conv.push({ role: "tool", tool_call_id: tc.id, content: JSON.stringify(result) });
      }
    }

    send("error", { message: "Max tool call rounds exceeded" });
    res.end();
  } catch (err) {
    send("error", { message: err.message });
    res.end();
  }
});

app.listen(PORT, () => {
  console.log(`\n  🚀 Foundry Chat running at  http://localhost:${PORT}`);
  console.log(`  📡 Foundry Local backend    ${FOUNDRY_BASE}`);
  console.log(`  🔧 Tools loaded: ${[...tools.keys()].join(", ") || "none"}\n`);
});
