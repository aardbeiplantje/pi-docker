import httpx
from pathlib import Path


def save_slot(server_url, slot_id, cache_name, cache_dir, model=None):
    """Save slot KV cache by POSTing to llama.cpp server."""
    payload = {"filename": cache_name, "model": model} if model else {"filename": cache_name}

    url = f"{server_url}/slots/{slot_id}?action=save"
    try:
        resp = httpx.post(url, json=payload, timeout=30)
        resp.raise_for_status()
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            return False
        raise
    except httpx.HTTPError as e:
        raise

    return True


def restore_slot(server_url, slot_id, cache_name, cache_dir, model=None):
    """Restore slot KV cache by POSTing to llama.cpp server."""
    payload = {"filename": cache_name, "model": model} if model else {"filename": cache_name}

    try:
        url = f"{server_url}/slots/{slot_id}?action=restore"
        resp = httpx.post(url, json=payload, timeout=30)
        resp.raise_for_status()
        return True
    except httpx.HTTPError as e:
        return False
