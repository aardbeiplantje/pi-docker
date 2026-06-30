// opencode plugin: llama.cpp slot cache manager
//
// Bridges OpenCode session lifecycle to llama.cpp server slot management.
// - Saves slot KV cache on session.compacted / session.deleted events
// - Periodically saves slot KV cache on idle intervals (configurable)
// - Injects id_slot parameter into chat requests (when cache exists)
//
// Requires: python3 installed in the container
// llama.cpp server must be configured with: --slot-save-path <dir>

const PLUGIN_DIR = new URL(import.meta.url).pathname.substring(
  0, new URL(import.meta.url).pathname.lastIndexOf('/')
)
const PYTHON_SCRIPT = PLUGIN_DIR + '/slot_cache.py'

const LOG_FILE = `${PLUGIN_DIR}/slot_cache.log`

let logFd = null

async function openLogFile() {
  if (logFd) return logFd
  try {
    const fs = await import('fs/promises')
    const path = await import('path')
    const logDir = path.dirname(LOG_FILE)
    await fs.mkdir(logDir, { recursive: true })
    logFd = await fs.open(LOG_FILE, 'a')
    return logFd
  } catch (e) {
    return null
  }
}

async function logToFile(level, message) {
  const timestamp = new Date().toISOString()
  const entry = `[${timestamp}] [slot-cache] [${level}] ${message}\n`
  try {
    const fd = await openLogFile()
    if (fd) {
      await fd.write(entry)
    }
  } catch (e) {
    // silently ignore logging failures
  }
}

async function closeLogFile() {
  if (logFd) {
    try {
      await logFd.close()
    } catch (e) {
      // ignore
    }
    logFd = null
  }
}

async function showToastVariant($, cacheName, serverUrl, variant, title, action) {
    if (!cacheName) return
    const now = new Date().toLocaleString()
    const message = `${action} — ${cacheName} at ${now} — ${serverUrl}`
    try {
      const tui = $.client?.tui
      if (tui && tui.showToast) {
        tui.showToast({ title, message, variant, duration: 3000 })
        logToFile('INFO', `toast: ${variant} — ${message}`)
      } else {
        logToFile('INFO', `toast API not available (variant=${variant}, title=${title})`)
      }
    } catch (e) {
      logToFile('WARN', `toast error: ${e.message || e}`)
    }
}

async function runPython(args) {
  try {
    const child = Bun.spawn(
      ['python3', PYTHON_SCRIPT, ...args],
      {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: { ...process.env, PYTHONUNBUFFERED: '1' },
      }
    )
    const exitCode = await child.exited
    return { exitCode }
  } catch (e) {
    logToFile('ERROR', `spawn error: ${e.message || e}`)
    return { exitCode: -1 }
  }
}

export const SlotCachePlugin = async ({ directory, $, dispose }) => {
  const RAW_URL = process.env.LLAMA_SERVER_URL || 'http://[::1]:8000'
  const LLAMA_SERVER_URL = RAW_URL.replace(/\/v1(\/.*)?$/, '')
  const USER = process.env.UID || process.env.USER || process.env.LOGNAME || 'node'
  const SLOT_ID = parseInt(process.env.SLOT_ID || '0', 10)
  const SAVE_INTERVAL_MS = parseInt(process.env.SLOT_SAVE_INTERVAL_MS || '300000', 10)
  const CACHE_BASE_DIR = process.env.HOME || '/home/node'
  const SLOT_CACHE_DIR = `${CACHE_BASE_DIR}/.cache/llama-slots`
  const MODEL_NAME = process.env.LLAMA_MODEL || ''

  function makeCacheName(sessionId) {
    const modelId = MODEL_NAME || 'default'
    const modelShort = modelId.split('/').pop().split(':').shift().replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30)
    if (!directory) return `${USER}_${modelShort}_root_${sessionId?.slice(0,8) || 'none'}`
    const parts = directory.split('/').filter(Boolean)
    const base = parts[parts.length - 1].replace(/[^a-zA-Z0-9]/g, '_').slice(0, 30)
    return `${USER}_${modelShort}_${base}_${sessionId?.slice(0,8) || 'none'}`
  }

  let slotApiAvailable = true
  let currentSessionId = null
  let cacheName = null
  let lastChatParamsTime = 0

  function slotApiUnav() {
    if (slotApiAvailable) {
      slotApiAvailable = false
      logToFile('ERROR', `slots API unavailable on ${LLAMA_SERVER_URL} — KV cache persistence disabled`)
      if (idleTimerId) {
        clearInterval(idleTimerId)
        idleTimerId = null
      }
    }
  }

  async function tryRestore(name) {
    if (!slotApiAvailable || !name) return
    try {
      const { exitCode } = await pythonRun(
        ['restore', LLAMA_SERVER_URL, String(SLOT_ID), name, SLOT_CACHE_DIR, '--model', MODEL_NAME],
        'try restore'
      )
      if (exitCode === 0) {
        logToFile('INFO', `restored slot ${SLOT_ID} from cache, exitCode=${exitCode}`)
        showToastVariant($, name, LLAMA_SERVER_URL, 'success', 'Slot Cache', 'Restored')
      } else {
        logToFile('INFO', `no cache to restore for slot ${SLOT_ID}, exitCode=${exitCode}`)
      }
    } catch (e) {
      logToFile('WARN', `restore error: ${e.message || e}`)
    }
  }

  async function updateCacheName(sessionId) {
    if (sessionId && sessionId !== currentSessionId) {
      currentSessionId = sessionId
      cacheName = makeCacheName(sessionId)
      logToFile('INFO', `cache name updated to "${cacheName}" for session ${sessionId.slice(0,8)}`)
    }
  }

  async function pythonRun(args, logPrefix) {
    const cmdStr = `python3 ${PYTHON_SCRIPT} ${args.join(' ')}`
    logToFile('INFO', `${logPrefix}: ${cmdStr}`)
    return await runPython(args)
  }

  // Periodic idle save timer
  let idleTimerId = null
  async function periodicSave() {
    if (!slotApiAvailable || !cacheName) return
    const idleMs = Date.now() - lastChatParamsTime
    if (idleMs > 60000) {
      logToFile('INFO', `periodic save skipped — session idle for ${Math.round(idleMs / 1000)}s`)
       showToastVariant($, cacheName, LLAMA_SERVER_URL, 'warning', 'Slot Cache', `Skipped (idle ${Math.round(idleMs / 1000)}s)`)
      return
    }
    try {
      const exitCode = await pythonRun(
        ['save', LLAMA_SERVER_URL, String(SLOT_ID), cacheName, SLOT_CACHE_DIR, '--model', MODEL_NAME],
        'periodic save'
      )
      if (exitCode === 0) {
        logToFile('INFO', `saved slot ${SLOT_ID} (interval save), exitCode=${exitCode}`)
        showToastVariant($, cacheName, LLAMA_SERVER_URL, 'success', 'Slot Cache', 'Saved')
      } else {
        logToFile('WARN', `periodic save failed for slot ${SLOT_ID}, exitCode=${exitCode}`)
        showToastVariant($, cacheName, LLAMA_SERVER_URL, 'error', 'Slot Cache', 'Periodic save failed')
      }
    } catch (e) {
      logToFile('ERROR', `periodic save error: ${e.message || e}`)
      showToastVariant($, cacheName, LLAMA_SERVER_URL, 'error', 'Slot Cache', 'Periodic save error')
    }
  }
  idleTimerId = setInterval(periodicSave, SAVE_INTERVAL_MS)

  // Dispose cleanup
  if (dispose) {
    dispose(async () => {
      if (idleTimerId) {
        clearInterval(idleTimerId)
        idleTimerId = null
      }
      if (cacheName) {
        try {
          const { exitCode } = await pythonRun(
            ['save', LLAMA_SERVER_URL, String(SLOT_ID), cacheName, SLOT_CACHE_DIR, '--model', MODEL_NAME],
            'save on exit'
          )
          if (exitCode === 0) {
            logToFile('INFO', `saved slot ${SLOT_ID} on exit, exitCode=${exitCode}`)
            showToastVariant($, cacheName, LLAMA_SERVER_URL, 'success', 'Slot Cache', 'Saved on exit')
          } else {
            logToFile('WARN', `save on exit failed for slot ${SLOT_ID}, exitCode=${exitCode}`)
            showToastVariant($, cacheName, LLAMA_SERVER_URL, 'error', 'Slot Cache', 'Save on exit failed')
          }
        } catch (e) {
          logToFile('ERROR', `save on exit error: ${e.message || e}`)
          showToastVariant($, cacheName, LLAMA_SERVER_URL, 'error', 'Slot Cache', 'Save on exit error')
        }
      }
      await closeLogFile()
    })
  }

  return {
    // Subscribe to session lifecycle events
    event: async ({ event }) => {
      if (!slotApiAvailable) return
     try {
        // Initialize cache name on session creation; save on compact/delete
        if (event.type === 'session.created' || event.type === 'session.create') {
           const sid = event.properties?.sessionID || event.properties?.info?.sessionID
           if (sid) {
             updateCacheName(sid)
             await tryRestore(cacheName)
           }
         }
        if (event.type === 'session.compacted' || event.type === 'session.deleted') {
          logToFile('INFO', `got {event.type}`)
          if (!cacheName) {
            const sid = event.properties?.sessionID || event.properties?.info?.sessionID
            if (sid) updateCacheName(sid)
          }
          if (cacheName) {
            const { exitCode } = await pythonRun(
              ['save', LLAMA_SERVER_URL, String(SLOT_ID), cacheName, SLOT_CACHE_DIR, '--model', MODEL_NAME],
              `save on ${event.type}`
            )
            if (exitCode === 0) {
              logToFile('INFO', `saved slot ${SLOT_ID} on ${event.type}, exitCode=${exitCode}`)
              showToastVariant($, cacheName, LLAMA_SERVER_URL, 'success', 'Slot Cache', `Saved on ${event.type.replace('session.', '')}`)
            } else {
              logToFile('WARN', `save on ${event.type} failed for slot ${SLOT_ID}, exitCode=${exitCode}`)
              showToastVariant($, cacheName, LLAMA_SERVER_URL, 'error', 'Slot Cache', `${event.type.replace('session.', '')} save failed`)
            }
          }
        }
      } catch (e) {
        logToFile('ERROR', `event handler error for ${event.type}: ${e.message || e}`)
      }
    },

    // Inject id_slot into chat requests to use the cached slot
    'chat.params': async (input, output) => {
      lastChatParamsTime = Date.now()
      logToFile('INFO', `got chat.params ${input}`)
      if (!slotApiAvailable) return
      if (!cacheName) {
        logToFile('INFO', 'chat.params: no cache name yet, skipping')
        return
      }
      if(input && input.model) {
        if (!input.model.extraBody) {
          input.model.extraBody = {}
        }
        input.model.extraBody.id_slot = SLOT_ID
        logToFile('INFO', `injected id_slot=${SLOT_ID}`)
      }
    }
  }
}
