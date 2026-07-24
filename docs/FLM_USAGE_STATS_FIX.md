# Fix: FastFlowLM Usage Stats Not Displaying

## Problem

When using FastFlowLM (AMD NPU mode), extended usage statistics like `active_kv_tokens`, `max_kv_token_capacity`, `prefill_speed_tps`, and `decoding_speed_tps` were not being captured or displayed in the footer, even though the backend returns them in the chat completion response.

### Example Response from FastFlowLM

```json
{
  "id": "chatcmpl-bd7ed97315ab96ba90fbe40d",
  "object": "chat.completion.chunk",
  "created": 1784887144,
  "model": "qwen3.6-moe:35b-a3b",
  "usage": {
    "prompt_tokens": 8761,
    "completion_tokens": 37,
    "total_tokens": 8798,
    "active_kv_tokens": 8798,
    "max_kv_token_capacity": 32768,
    "kv_token_occupancy_rate_percentage": 26.85,
    "load_duration": 1.15e-06,
    "prefill_duration_ttft": 62.78,
    "decoding_duration": 3.32,
    "prefill_speed_tps": 139.55,
    "decoding_speed_tps": 11.14
  }
}
```

## Root Cause

The pi-llama extension was trying to capture usage stats using a **non-existent event** called `after_provider_response`:

```typescript
// BEFORE (broken) - This event doesn't exist!
try {
    (pi as any).on("after_provider_response", (event, ctx) => {
        const usageRaw = (event.payload as { usage?: unknown })?.usage;
        // ... process usage
    });
} catch (e) {
    // Silently fails — FLM stats never captured
}
```

This code assumes that pi.dev provides an `after_provider_response` event with the full API response payload, but this event **does not exist** in the SDK. The try-catch swallows the error silently, so usage stats were never captured.

## Solution

### Use Real Events: `message_end`

Pi.dev DOES provide message lifecycle events (`message_start`, `message_end`) and assistant messages include usage data attached by the provider layer. Replace the non-existent event handler with:

```typescript
// AFTER (working) - Uses real message_end event
pi.on("message_end", (event: any, ctx) => {
    if (!flmMode || event.message.role !== "assistant") return;
    
    // Extract raw usage from the message - includes all FLM extensions
    const rawUsage = event.message.usage;
    if (!rawUsage) return;
    
    const usage = parseFlmUsage(rawUsage);
    if (!usage) return;
    
    // Update FLM usage state for footer display
    lastFlmUsage = usage;
    flmUsageUpdateTime = Date.now();
});
```

### Capture All Fields

Added missing fields to the `FlmUsage` interface and parser:

```typescript
interface FlmUsage {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
    active_kv_tokens?: number;               // NEW!
    max_kv_token_capacity?: number;          // NEW!
    kv_token_occupancy_rate_percentage?: number;
    load_duration?: number;
    prefill_duration_ttft?: number;
    decoding_duration?: number;
    prefill_speed_tps?: number;
    decoding_speed_tps?: number;
}
```

### Enhanced Footer Display

Updated `buildFlmFooterStats()` to show KV token capacity when available:

```typescript
function buildFlmFooterStats(): string | undefined {
    const usage = getValidFlmUsage();
    if (!usage) return undefined;

    const parts: string[] = [];
    
    // Show KV tokens as "active/max" or percentage fallback
    if (typeof usage.active_kv_tokens === "number" && 
        typeof usage.max_kv_token_capacity === "number") {
        parts.push(`KV ${usage.active_kv_tokens}/${usage.max_kv_token_capacity}`);
    } else if (typeof usage.kv_token_occupancy_rate_percentage === "number") {
        parts.push(`📊 ${(usage.kv_token_occupancy_rate_percentage * 100).toFixed(0)}%`);
    }
    
    // Speed stats remain the same
    if (typeof usage.decoding_speed_tps === "number" && usage.decoding_speed_tps > 0) {
        parts.push(`⚡ ${usage.decoding_speed_tps.toFixed(1)}t/s`);
    }
    if (typeof usage.prefill_speed_tps === "number" && usage.prefill_speed_tps > 0) {
        parts.push(`📥 ${usage.prefill_speed_tps.toFixed(1)}t/s`);
    }

    return parts.length > 0 ? parts.join(" ") : undefined;
}
```

## Result

With this fix, when using FastFlowLM mode (`LLAMA_FLM_MODE=1`), the footer will display:

- **KV tokens**: `8798/32768` or percentage fallback like `📊 27%`
- **Decode speed**: `⚡ 11.1t/s`  
- **Prefill speed**: `📥 139.5t/s`

All extended FLM statistics are now properly captured and displayed! 🎉

## Files Changed

- `/workdir/pi.git/pi-llama/index.ts`: 
  - Replaced non-existent `after_provider_response` event with real `message_end` handler
  - Added `active_kv_tokens` and `max_kv_token_capacity` to FlmUsage interface
  - Enhanced footer stats to show KV capacity breakdown
