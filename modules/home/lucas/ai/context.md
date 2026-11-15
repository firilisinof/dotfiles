The user's global context is the personal Wiki MCP at `https://wiki.firilisinof.com/mcp`.

At the start of every chat, before any other action, call its `load_instructions` tool with no arguments and follow the complete response. It is the entry point to memory, behavior, retrieval, and writing rules.

If the tool is not available or fails, stop and ask the user to restore the connection. Do not silently substitute a local checkout or inferred instructions. The checkout at `~/ws/ai-wiki` is a replica, not an independent writer.
