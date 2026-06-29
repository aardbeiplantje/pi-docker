"""Custom LiteLLM provider for llama.cpp embedding models.

This module registers a custom LiteLLM provider that handles llama.cpp's
non-standard embedding response format where the embedding vector is wrapped
in an extra array layer: [[...]] instead of [...].

Usage:
    from cocoindex_plugins.llamacpp_provider import register_llamacpp_provider
    register_llamacpp_provider()

When configured, use custom_llm_provider='llamacpp' in your LiteLLM calls:
    litellm.embedding(
        model='embeddinggemma-300M-Q8_0',
        input='hello world',
        custom_llm_provider='llamacpp',
        api_base='http://localhost:8000',
        api_key='nokeyneeded'
    )
"""

import litellm


def _build_handler():
    """Build and return a LiteLLM-compatible embedding handler for llama.cpp."""
    
    class LlamaCppEmbeddingHandler:
        """Custom LiteLLM handler for llama.cpp embedding models.
        
        Handles llama.cpp's non-standard embedding response format:
        - llama.cpp returns: [{"index": 0, "embedding": [[...]]}]
        - OpenAI expects:    {"data": [{"index": 0, "embedding": [...]}]}
        """
        
        def __init__(self):
            import concurrent.futures
            self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=4)
        
        def embedding(self, model, input, logging_obj, api_base, api_key, 
                      timeout, optional_params, model_response, print_verbose, 
                      litellm_params, **kwargs):
            """Handle sync embedding requests by delegating to async impl."""
            print_verbose(f"Custom llama.cpp embedding handler called for model={model}")
            
            def _run():
                import asyncio
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    return loop.run_until_complete(
                        self._aembedding(
                            model=model, input=input, logging_obj=logging_obj,
                            api_base=api_base, api_key=api_key, timeout=timeout,
                            optional_params=optional_params, model_response=model_response,
                            print_verbose=print_verbose, litellm_params=litellm_params, **kwargs
                        )
                    )
                finally:
                    loop.close()
            
            return _run()
        
        async def aembedding(self, model, input, logging_obj, api_base, api_key, 
                             timeout, optional_params, model_response, print_verbose, 
                             litellm_params, aembedding=True, **kwargs):
            """Handle async embedding requests (required by litellm.aembedding)."""
            return await self._aembedding(
                model=model, input=input, logging_obj=logging_obj,
                api_base=api_base, api_key=api_key, timeout=timeout,
                optional_params=optional_params, model_response=model_response,
                print_verbose=print_verbose, litellm_params=litellm_params, **kwargs
            )
        
        async def _aembedding(self, model, input, logging_obj, api_base, api_key, 
                              timeout, optional_params, model_response, print_verbose, 
                              litellm_params, **kwargs):
            """Handle async embedding requests via direct HTTP call."""
            import os
            import httpx
            from litellm.types.utils import Embedding, Usage
            
            data = {
                "model": model,
                "input": input if isinstance(input, list) else [input],
                "encoding_format": optional_params.get("encoding_format", "float")
            }
            if not api_base:
                api_base = (litellm_params or {}).get("api_base") or os.environ.get("OPENAI_BASE_URL") or ""
            base_url = api_base.rstrip("/")
            endpoint = f"{base_url}/v1/embeddings"
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(endpoint, json=data, headers=headers)
                response.raise_for_status()
                raw_json = response.json()
            
            if isinstance(raw_json, list):
                # llama.cpp returns list format: [{"index": 0, "embedding": [[...]]}]
                data_items = []
                for item in raw_json:
                    emb = item.get("embedding", [])
                    # Flatten nested array [[...]] -> [...]
                    if isinstance(emb, list) and len(emb) > 0 and isinstance(emb[0], list):
                        emb = emb[0]
                    data_items.append(Embedding(
                        index=item.get("index", 0),
                        embedding=emb,
                        object="embedding"
                    ))
                model_response.model = model
                model_response.object = "list"
                model_response.data = data_items
                model_response.usage = Usage(prompt_tokens=0, total_tokens=0)
                return model_response
            else:
                # Standard OpenAI format - passthrough
                model_response.model = raw_json.get("model", model)
                model_response.object = raw_json.get("object", "list")
                data = raw_json.get("data", [])
                if isinstance(data, list):
                    model_response.data = [
                        Embedding(
                            index=item.get("index", 0),
                            embedding=item.get("embedding", []),
                            object="embedding"
                        )
                        for item in data
                    ]
                else:
                    model_response.data = []
                usage = raw_json.get("usage", {})
                model_response.usage = Usage(
                    prompt_tokens=usage.get("prompt_tokens", 0),
                    total_tokens=usage.get("total_tokens", 0)
                )
                return model_response
    
    return LlamaCppEmbeddingHandler()


def register_llamacpp_provider():
    """Register the llama.cpp embedding provider with LiteLLM.
    
    Call this function once at application startup before making any
    embedding requests via LiteLLM.
    
    Example:
        from cocoindex_plugins.llamacpp_provider import register_llamacpp_provider
        register_llamacpp_provider()
        
        result = litellm.embedding(
            model='embeddinggemma-300M-Q8_0',
            input='hello',
            custom_llm_provider='llamacpp',
            api_base='http://localhost:8000'
        )
    """
    handler = _build_handler()
    litellm.custom_provider_map.append({
        "provider": "llamacpp",
        "custom_handler": handler
    })


def is_registered():
    """Check if the llamacpp provider has been registered."""
    for entry in litellm.custom_provider_map:
        if entry.get("provider") == "llamacpp":
            return True
    return False
