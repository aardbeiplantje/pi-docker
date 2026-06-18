import asyncio
import subprocess
import sys
from mcp.server.models import InitializationOptions
import mcp.types as types
from mcp.server import NotificationOptions, Server
from mcp.server.stdio import stdio_server

server = Server("ccc-granular")

@server.list_tools()
async def handle_list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="ccc_init",
            description="Initialize a project for cocoindex-code",
            inputSchema={
                "type": "object",
                "properties": {},
            },
        ),
        types.Tool(
            name="ccc_index",
            description="Create/update index for the codebase",
            inputSchema={
                "type": "object",
                "properties": {},
            },
        ),
        types.Tool(
            name="ccc_search",
            description="Semantic search across the codebase",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "The search query"},
                },
                "required": ["query"],
            },
        ),
        types.Tool(
            name="ccc_status",
            description="Show project status",
            inputSchema={
                "type": "object",
                "properties": {},
            },
        ),
        types.Tool(
            name="ccc_reset",
            description="Reset project databases and optionally remove settings",
            inputSchema={
                "type": "object",
                "properties": {
                    "force": {"type": "boolean", "description": "Force reset"},
                },
            },
        ),
        types.Tool(
            name="ccc_doctor",
            description="Check system health and report issues",
            inputSchema={
                "type": "object",
                "properties": {},
            },
        ),
        types.Tool(
            name="ccc_daemon_restart",
            description="Restart the ccc daemon",
            inputSchema={
                "type": "object",
                "properties": {},
            },
        ),
    ]

@server.call_tool()
async def handle_call_tool(
    name: str, arguments: dict | None
) -> list[types.TextContent | types.ImageContent | types.EmbeddedResource]:
    if name == "ccc_init":
        cmd = ["ccc", "init"]
    elif name == "ccc_index":
        cmd = ["ccc", "index"]
    elif name == "ccc_search":
        if not arguments or "query" not in arguments:
            raise ValueError("Missing 'query' argument")
        cmd = ["ccc", "search", arguments["query"]]
    elif name == "ccc_status":
        cmd = ["ccc", "status"]
    elif name == "ccc_reset":
        cmd = ["ccc", "reset"]
        if arguments and arguments.get("force"):
            cmd.append("-f")
    elif name == "ccc_doctor":
        cmd = ["ccc", "doctor"]
    elif name == "ccc_daemon_restart":
        cmd = ["ccc", "daemon", "restart"]
    else:
        raise ValueError(f"Unknown tool: {name}")

    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await process.communicate()

    result = stdout.decode().strip()
    if stderr.decode().strip():
        result += "\n" + stderr.decode().strip()

    return [types.TextContent(type="text", text=result)]

async def main():
    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="ccc-granular",
                server_version="0.1.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )

if __name__ == "__main__":
    asyncio.run(main())
