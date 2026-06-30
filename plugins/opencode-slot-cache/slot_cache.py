#!/usr/bin/env python3
"""
llama.cpp slot cache manager CLI.

Wraps slot_cache_lib for command-line usage.
"""
import sys
import argparse
import httpx
from slot_cache_lib import save_slot, restore_slot


def main():
    parser = argparse.ArgumentParser(description="llama.cpp slot cache manager")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # save
    save_parser = subparsers.add_parser("save", help="Save slot KV cache to remote server")
    save_parser.add_argument("server_url", help="llama.cpp server base URL")
    save_parser.add_argument("slot_id", type=int, help="Slot ID to manage")
    save_parser.add_argument("cache_name", help="Cache name")
    save_parser.add_argument("cache_dir", help="Directory for cache files")
    save_parser.add_argument("--model", default=None, help="Model name")

    # restore
    restore_parser = subparsers.add_parser("restore", help="Restore slot KV cache from remote server")
    restore_parser.add_argument("server_url", help="llama.cpp server base URL")
    restore_parser.add_argument("slot_id", type=int, help="Slot ID to manage")
    restore_parser.add_argument("cache_name", help="Cache name")
    restore_parser.add_argument("cache_dir", help="Directory for cache files")
    restore_parser.add_argument("--model", default=None, help="Model name")

    args = parser.parse_args()

    try:
        if args.command == "save":
            result = save_slot(args.server_url, args.slot_id, args.cache_name, args.cache_dir, model=args.model)
            if result:
                print(f"save: OK (slot {args.slot_id}, cache '{args.cache_name}')")
            else:
                print(f"save: FAILED (slot {args.slot_id}, cache '{args.cache_name}')")
            sys.exit(0 if result else 1)

        elif args.command == "restore":
            result = restore_slot(args.server_url, args.slot_id, args.cache_name, args.cache_dir, model=args.model)
            if result:
                print(f"restore: OK (slot {args.slot_id}, cache '{args.cache_name}')")
            else:
                print(f"restore: FAILED (slot {args.slot_id}, cache '{args.cache_name}')")
            sys.exit(0 if result else 1)

    except httpx.HTTPStatusError as e:
        print(f"HTTP error: {e.response.status_code} - {e.response.text}")
        sys.exit(1)
    except httpx.ConnectError as e:
        print(f"Connection error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
