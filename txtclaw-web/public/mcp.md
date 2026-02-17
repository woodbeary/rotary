# TXT CLAW MCP (Preview)

MCP is an optional lane for coding agents that want tools and structured operations.

Today:
- Use the TXT CLAW HTTP API (OpenAPI + agent-friendly Markdown).
- MCP server is coming soon (HTTP API works today).

```bash
pnpm dlx txtclaw@latest init --mcp
```

Docs to paste into agents:
- `https://www.txtclaw.com/agents.md`
- `https://www.txtclaw.com/openapi.yaml`

## MCP server

MCP server package publishing is in progress. Until then, use the HTTP API.

When published, it will run like this (no global install):

```bash
pnpm dlx -s txtclaw-mcp@latest
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
