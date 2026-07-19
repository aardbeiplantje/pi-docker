# Fix: LLAMA_SLOT_ID Range Not Respected for Main Agent

## Problem

When `LLAMA_SLOT_ID=1-6` is set, the main agent was still using slot 0, even though slot 0 is not in the configured pool. This caused conflicts and prevented proper slot isolation between the main agent and sub-agents.

## Root Cause Analysis

### Bug 1: Main Agent Slot Hardcoded to 0

**File:** `pi-llama/index.ts` (lines 249-255)

```typescript
// BEFORE
const allSlots = parseSlotRange(process.env.LLAMA_SLOT_ID);
const mainAgentId = "main";
const mainAgentSlot = 0;  // ← Hardcoded!
const sas = allSlots.filter(s => s !== mainAgentSlot);
const slotPool = createSlotPool(sas);
let currentSlotId = mainAgentSlot;
```

When `LLAMA_SLOT_ID=1-6`:
- `allSlots = [1,2,3,4,5,6]`
- `mainAgentSlot = 0` (hardcoded, not in pool!)
- `sas = [1,2,3,4,5,6]` (all slots remain since 0 isn't in the list)
- `currentSlotId = 0` ← **BUG: main agent uses slot 0 which doesn't exist**

### Bug 2: `subagents:started` Event Missing `agentId` Field

**File:** `pi-subagents/src/index.ts` (line 442)

```typescript
// BEFORE
pi.events.emit("subagents:started", {
  id: record.id,
  type: record.type,
  description: record.description,
});
```

The event only had `id`, but pi-llama's listener expects `agentId` for cross-extension communication.

### Bug 3: Session Name Short ID Not Matched in Slot Lookup

**File:** `pi-llama/index.ts` (lines 700-712)

The `before_provider_request` handler extracts the first 8 chars of the agent ID from the session name:
```typescript
const sessionName = ctx.sessionManager?.getSessionName?.() ?? "";
if (sessionName && sessionName.includes("#")) {
  const parts = sessionName.split("#");
  const agentId = parts.length > 1 ? parts[1] : sessionName;  // short ID!
  if (ssubAgentSlots.has(agentId)) { ... }  // ← Never matches!
}
```

But `ssubAgentSlots` was only keyed by the full UUID from `record.id`. The session name uses `agentId.slice(0, 8)` (see `agent-runner.ts` line 711), so the lookup never found sub-agents.

## Fix

### Fix 1: Dynamic Main Agent Slot

```typescript
// AFTER
const mainAgentSlot = allSlots.includes(0) ? 0 : allSlots[0];
```

When slot 0 is in the pool, use it. Otherwise, use the first available slot.

### Fix 2: Add `agentId` to Event

```typescript
// AFTER
pi.events.emit("subagents:started", {
  agentId: record.id,  // ← Added for cross-extension use
  id: record.id,
  type: record.type,
  description: record.description,
});
```

### Fix 3: Store Short ID Alias

```typescript
// AFTER (in subagents:started listener)
const shortId = agentId.slice(0, 8);
if (shortId !== agentId) {
  ssubAgentSlots.set(shortId, ssubAgentSlots.get(agentId)!);
}
```

Now the session name lookup in `before_provider_request` can find sub-agents by their short ID.

## Result

With `LLAMA_SLOT_ID=1-6`:

| Agent | Slot |
|-------|------|
| Main agent | 1 (first in pool) |
| Sub-agent 1 | 2 |
| Sub-agent 2 | 3 |
| Sub-agent 3 | 4 |
| Sub-agent 4 | 5 |
| Sub-agent 5 | 6 |
| Manual (r.sh 7) | 7 |

## Files Changed

- `pi-llama/index.ts` — Dynamic main agent slot, short ID alias storage
- `pi-subagents/src/index.ts` — Added `agentId` to `subagents:started` event

## Testing

```bash
# Verify slot assignment
env | grep LLAMA_SLOT_ID  # Should show LLAMA_SLOT_ID=1-6

# Test manual slot 7 (should work)
bash ~/r.sh 7

# Sub-agents should now use slots 2-6 automatically
```
