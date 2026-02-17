# TXT CLAW MCP (Preview)

MCP is an optional lane for coding agents that want tools and structured operations.

Today:
- Use the TXT CLAW HTTP API (OpenAPI + agent-friendly Markdown).
- Or run the MCP server for tool-based workflows.

```bash
pnpm dlx txtclaw@latest init --mcp
```

Docs to paste into agents:
- `https://www.txtclaw.com/agents.md`
- `https://www.txtclaw.com/openapi.yaml`

## MCP server

Run the MCP server (no global install):

```bash
pnpm -s dlx txtclaw-mcp@latest
```

Environment:

- `TXTCLAW_API_KEY` (required)
- `TXTCLAW_API_BASE_URL` (optional)

Tools:

- `txtclaw_status`
- `txtclaw_create_agent`
- `txtclaw_get_agent`
- `txtclaw_send_message`
- `txtclaw_byok_get`
- `txtclaw_byok_set`
- `txtclaw_byok_clear`
