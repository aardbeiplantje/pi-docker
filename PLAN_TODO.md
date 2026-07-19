# PLAN / TODO — Slot ID System

> Last updated: 2025-07-15

## Overview

The slot ID system manages llama.cpp KV cache slots to prevent cache eviction when sub-agents run concurrently with the main agent.

---

## Current Architecture

### Default Configuration
| Component | Value | Location |
|-----------|-------|----------|
| Default slot ID | `0` | `pi-llama/index.ts:25` |
| Branch | `feat/llama-slot-id-env-var` | `Dockerfile` |
| Max concurrent sub-agents | `1` | `pi_settings.json` |

### How It Works
1. **Slot pool** parses `LLAMA_SLOT_ID` env var as a range (e.g., `"0-3"`)
2. **Main agent** gets assigned first available slot (defaults to `0`)
3. **Sub-agents** auto-assign from pool via `subagents:started` event
4. **Injection**: `slot_id` is added to every provider request payload

### Key Files
- `pi-llama/index.ts` — Slot pool allocator, event listeners, request injection
- `pi_settings.json` — `subagents.maxConcurrent` setting
- `Dockerfile` — `PI_LLAMA_SHA` default branch

---

## TODO

### High Priority
- [x] **Fix `pi.pl` env var name** — `SLOT_ID` → `LLAMA_SLOT_ID` (commit `18b09af`)
- [x] **Fix llama.cpp API key** — `slot_id` → `id_slot` (commit `3ceff1a`)
- [x] **Fix slot release** — Clean up both agentId and slot value from pool (commit `05035b1`)
- [ ] **Investigate full prompt prefill** — Slot 1 used but KV cache not preserved (see issue below)
- [ ] **Test slot pool with multiple sub-agents** — Verify auto-assignment works when `maxConcurrent > 1`

### Medium Priority
- [ ] **Add slot health checks** — Detect stale/evicted slots and reassign
- [ ] **Support dynamic pool resizing** — Allow adding slots at runtime via command
- [ ] **Log slot contention** — Track when all slots are allocated

### Low Priority
- [ ] **Add slot metrics** — Expose pool stats via `/metrics` endpoint or CLI command
- [ ] **Support per-model slot ranges** — Different models can use different slot pools
- [ ] **Cleanup on session shutdown** — Ensure all slots are released when session ends

---

## Known Issues

### Full Prompt Prefill on Slot 1
- **Symptom**: Requests go to slot 1 (confirmed via logs), but still see full prefill (~127s for ~56k tokens)
- **llama.cpp config**: `--slot-save-path /llama.cpp/slots` is set
- **Possible causes**:
  - Cache not loading from disk on slot reuse
  - `--slot-prompt-similarity 0.90` threshold too high, causing cache invalidation
  - Idle slot cache being cleared before next request
- **Next step**: Check `/llama.cpp/slots/` directory for saved cache files; verify cache is being loaded on subsequent requests

---

## Git History (Slot-Related)

| Commit | Description |
|--------|-------------|
| `651581f` | Restructure Dockerfile for faster dev builds |
| `a03e984` | chore: update pi-llama submodule to debug logging |
| `46d94b0` | Update pi-llama to slot release fix |
| `86d0058` | Add `subagents.maxConcurrent=1` and update pi-llama to slot pool branch |
| `9a5bb45` | Add pi-subagents submodule with slot pool support |
| `5cd3904` | Update pi-llama submodule to dynamic slot pool HEAD |
| `aba235b` | feat(pi-llama): dynamic slot pool with auto-assignment |
| `8c343de` | Docs: add LLAMA_SLOT_ID env var documentation |
| `f9838b1` | fix: set PI_LLAMA_SHA default to feat/llama-slot-id-env-var branch |
| `43b8a52` | fix: use feat/llama-slot-id-env-var branch for pi-llama extension |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLAMA_SLOT_ID` | `0` | Slot ID or range (e.g., `"0"`, `"0-3"`) |
| `LLAMA_BASE_URL` | `http://localhost:8080/v1` | llama.cpp server URL |
| `LLAMA_API_KEY` | `no-key` | API key for authenticated servers |

## Range Format

```
"0"       → [0]
"0-3"     → [0, 1, 2, 3]
"5-7"     → [5, 6, 7]
""        → [0] (default)
invalid   → [0] (default, with warning)
```
