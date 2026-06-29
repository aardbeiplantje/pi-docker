#!/usr/bin/env python3
"""
Startup hook for CocoIndex - registers custom LiteLLM providers.

This script must be executed before the CocoIndex daemon starts to ensure
the llamacpp embedding provider is registered and available.
"""

import sys
import os

# Register the llamacpp embedding provider before CocoIndex uses LiteLLM
try:
    from cocoindex_plugins.llamacpp_provider import register_llamacpp_provider
    register_llamacpp_provider()
    print("✓ llamacpp embedding provider registered")
except ImportError as e:
    print(f"✗ Failed to register llamacpp provider: {e}", file=sys.stderr)
    # Non-fatal: proceed anyway in case llamacpp isn't needed
    print("  Continuing without llamacpp provider...", file=sys.stderr)
