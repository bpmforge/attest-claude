# Setup Guide

Step-by-step setup for a new machine. Covers prerequisites, installation, MCP configuration, and embedding model options.

---

## 1. Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Node.js** | 20–24 LTS | `install.sh` will prompt to install via NVM if wrong version |
| **git** | Any | For cloning MCPs |
| **jq** | Any | Used by the hooks to read tool-call JSON (macOS: `brew install jq`) |
| **Claude Code CLI** | Latest | `npm install -g @anthropic-ai/claude-code` |

Optional but recommended:
- **LM Studio** — embedding server for code-search, which needs one to build its index (and optionally for memory, which defaults to Ollama and falls back to keyword-only search without an embedder). See §3.
- **Semgrep** — for security audits (`pip install semgrep` or `brew install semgrep`)

---

## 2. Install

```bash
git clone https://github.com/bpmforge/attest-claude.git ~/Code/attest-claude
cd ~/Code/attest-claude
./install.sh
```

`install.sh` prompts y/n for each optional MCP, then clones, builds, and registers them. Pass `--yes` to accept all defaults without prompting. Useful flags: `--compact` (compact agent variants for 32k local models), `--tools` (also install the optional code-analysis tools — semgrep, knip, vulture, mmdc).

**What it installs:**
- Agents, skills, shared protocols, hooks, and scripts → `~/.claude/`
- `bpm-code-search-mcp` → `~/Code/bpm-code-search-mcp/` + registers as `code-search` MCP
- `bpm-memory-mcp` → `~/Code/bpm-memory-mcp/` + registers as `memory` MCP
- `playwright-mcp` → registered via `npx -y @playwright/mcp@latest`
- `playwright-search` → `~/.local/share/playwright-search/` + registers with Claude Code

---

## 3. Embedding model setup

Both `bpm-code-search-mcp` and `bpm-memory-mcp` use vector embeddings for semantic search, but they configure their embedders separately and behave differently without one:

- **code-search** reads environment variables (§4) and talks to LM Studio or another OpenAI-compatible server. `code_index` **needs a reachable embedding endpoint** — it embeds every chunk and refuses to run without one. Once an index exists, `code_search` degrades to keyword-only if the embedder later goes away, and `code_symbols` / `code_outline` / `code_references` never need it.
- **memory** reads `~/.claude-memory/config.json` (no environment variable selects the embedder). With no config file it uses **Ollama** at `http://localhost:11434` with `nomic-embed-text`. It works with no embedder at all: memories are stored without vectors and recall is keyword-only (BM25). The server re-probes its configured embedder at most every 30 s, so starting one later turns vector recall on without a restart.

### Option A — LM Studio (default for code-search, free, local)

1. Download [LM Studio](https://lmstudio.ai)
2. In the model search bar, find and download: `nomic-ai/nomic-embed-text-v1.5-GGUF`
3. Load it → it will listen on `http://localhost:1234`
4. No further config needed for code-search — it defaults to this URL and the model ID `text-embedding-nomic-embed-text-v1.5`. Memory uses LM Studio only when `~/.claude-memory/config.json` selects it — create that file yourself (see Option C).

### Option B — Different LM Studio model (code-search)

Any text embedding model loaded in LM Studio works. Set these env vars (add to `~/.zshrc` or `~/.bashrc`) — code-search reads them; memory does not:

```bash
export LM_STUDIO_MODEL="your-model-name-here"   # model ID as shown in LM Studio
export LM_STUDIO_URL="http://localhost:1234"     # server root, no /v1 — change if different
```

Common alternatives:

| Model | Dimensions | Speed | Quality |
|-------|-----------|-------|---------|
| `nomic-ai/nomic-embed-text-v1.5` | 768 | Fast | Good (default) |
| `text-embedding-nomic-embed-text-v1` | 768 | Fast | Good |
| `CompendiumLabs/bge-large-en-v1.5-gguf` | 1024 | Medium | Better |
| `CompendiumLabs/bge-small-en-v1.5-gguf` | 384 | Fastest | OK |

> **Important:** If you change the embedding model after indexing, you must re-index with `force=true`. code-search records the provider, model and vector dimension at index time; after a change, `code_search` and `code_index` refuse with a message until you run `code_index(force=true)`, which clears the old index and re-embeds every file. Memory is provider-sticky — after switching its model, run `memory_reembed()` to re-embed stored memories.

### Option C — Memory embedder (`~/.claude-memory/config.json`)

**Default (no config file):** install [Ollama](https://ollama.com) and run `ollama pull nomic-embed-text`. Nothing else to configure.

**LM Studio, another model, or a remote host** — create `~/.claude-memory/config.json`:

```json
{
  "embedding": {
    "provider": "lmstudio",
    "endpoint": "http://localhost:1234",
    "model": "text-embedding-nomic-embed-text-v1.5",
    "dimensions": 768
  },
  "version": 1
}
```

`provider` is `ollama` or `lmstudio`. `endpoint` is the server root — the client appends `/v1/embeddings` (LM Studio) or `/api/embeddings` (Ollama) itself.

`install.sh` registers the memory server (`claude mcp add memory ...`) but does not check, choose or configure its embedder — it never writes `config.json`. If you want LM Studio for memory, create the file above yourself.

### Option D — Other OpenAI-compatible servers (no hosted APIs)

Any server exposing `GET /v1/models` and `POST /v1/embeddings` works: point code-search's `LM_STUDIO_URL`, or memory's `endpoint` with `"provider": "lmstudio"`, at its root (the clients append `/v1/...` themselves, so do not include `/v1`). Neither server sends an API key or `Authorization` header, so hosted APIs that require one — OpenAI included — are **not supported**.

There is no switch to turn embeddings off: memory falls back to keyword-only on its own when its embedder is unreachable, and code-search cannot build an index without one.

---

## 4. MCP environment variables

All env vars can be set in `~/.zshrc` / `~/.bashrc`, or passed inline when starting Claude Code (the MCP servers inherit its environment). To store one on a server's registration instead, use `claude mcp add <name> -e KEY=value -- node <path>`.

### bpm-code-search-mcp

| Variable | Default | Purpose |
|----------|---------|---------|
| `CODE_SEARCH_ROOT` | `cwd` | Project root to index. Set per-project or leave as default. |
| `LM_STUDIO_URL` | `http://localhost:1234` | Embedding API base URL |
| `LM_STUDIO_MODEL` | `text-embedding-nomic-embed-text-v1.5` | Embedding model name |

**First-time per project:**
```
code_index()          # builds the index (takes ~30s for medium codebases)
code_index_status()   # verify: provider, files, chunks, symbols
```

`code_index` refuses to run until an embedder is reachable (§3). The index lives at `.code-search/index.db` under the project root (`CODE_SEARCH_ROOT`). The server does not gitignore it — add `.code-search/` to your `.gitignore`. Re-running `code_index()` refreshes it, skipping files whose mtime is unchanged.

### bpm-memory-mcp

The embedder is not set by environment variables — it comes from `~/.claude-memory/config.json` (§3, Option C). The server reads these:

| Variable | Default | Purpose |
|----------|---------|---------|
| `CLAUDE_PROJECT_ROOT` | `cwd` | Project whose memory database is used |
| `MEMORY_AGENT_ID` | _(unset)_ | Default writer/reader agent id for fleet-scoped memories |
| `MEMORY_TEAM_ID` | _(unset)_ | Default writer/reader team id for `team`-visibility memories |
| `CLAUDE_MEMORY_SLEEP_CONSOLIDATION` | `false` | Set to `true` to run consolidation automatically on `session_save` |
| `CLAUDE_MEMORY_CONSOLIDATION_INTERVAL_HOURS` | `24` | Minimum hours between automatic consolidation runs per project |
| `CLAUDE_MEMORY_CONSOLIDATION_LOG_PATH` | `~/.claude-memory/logs/consolidation.log` | Consolidation run log |

Each project gets its own database at `~/.claude-memory/<project-id>/memory.db`, where `<project-id>` is the first 16 hex characters of the SHA-256 of the project root path, so projects' memories are isolated automatically. The location is fixed — no variable overrides it.

### playwright-mcp

| Variable | Default | Purpose |
|----------|---------|---------|
| `PLAYWRIGHT_MCP_HEADED` | `false` | Set to `true` to see the browser while it runs |

**First use:** Chromium is auto-downloaded (~170 MB) on first browser launch. To pre-install:
```bash
npx playwright install chromium
```

---

## 5. Verify everything is working

```bash
# Check registered MCPs
claude mcp list

# Expected output includes:
#   code-search  node ~/Code/bpm-code-search-mcp/dist/index.js  - ✓ Connected
#   memory       node ~/Code/bpm-memory-mcp/mcp/memory-server/dist/index.js  - ✓ Connected
#   playwright   npx -y @playwright/mcp@latest  - ✓ Connected
#   playwright-search  node ~/.local/share/playwright-search/dist/mcp.js  - ✓ Connected
```

Then start a Claude Code session and test each MCP:
```
code_index_status()        # should show provider + file/chunk counts
session_restore()          # should return [] on a fresh install (no memories yet)
browser_navigate("https://example.com") && browser_screenshot()
```

---

## 6. LM Studio on a remote server

If LM Studio runs on a different machine (e.g., a home server):

```bash
export LM_STUDIO_URL="http://192.168.1.x:1234"   # code-search — replace with your server IP
```

Memory ignores that variable: set `"endpoint": "http://192.168.1.x:1234"` (with `"provider": "lmstudio"`) in `~/.claude-memory/config.json` instead (§3, Option C).

Make sure LM Studio is configured to accept connections on all interfaces (not just localhost) in its settings.

---

## 7. Troubleshooting

| Problem | Fix |
|---------|-----|
| `claude mcp list` shows MCP as "Pending approval" | Run `claude` interactively once and approve it |
| code-search: "No embedding provider available" | Start LM Studio (or the server at `LM_STUDIO_URL`) with an embedding model loaded, then retry — `code_index` cannot build an index without one |
| code-search: "The embedding model changed since this index was built" | Run `code_index(force=true)` to rebuild the index with the current model |
| memory: vector search returns 0 results | Its embedder isn't reachable, so recall is keyword-only. With no `~/.claude-memory/config.json` that embedder is Ollama with `nomic-embed-text` on port 11434; otherwise check the file's `provider`, `endpoint` and `model`. Then run `memory_reembed(onlyMissing=true)` to embed memories stored while it was down |
| playwright-mcp: "browser not found" | Run `npx playwright install chromium` |
| install.sh: "node not found" or wrong version | The installer will prompt to install NVM + Node 24 automatically |
| `jq: command not found` | `brew install jq` (macOS) or `apt install jq` (Linux) |
| MCP built but not registered | Re-run `./install.sh` or register manually: `claude mcp add <name> node <path>` |

---

## 8. Uninstall

```bash
./uninstall.sh
```

Removes all installed files from `~/.claude/`. Does not remove MCP repos from `~/Code/` or the memory databases and config under `~/.claude-memory/`.
