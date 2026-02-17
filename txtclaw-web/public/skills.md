# TXT CLAW Skills (OpenClaw / skills.sh)

TXT CLAW is designed to be easy for coding agents to discover and use:

- Agent-ingest docs: `https://www.txtclaw.com/quickstart.md`
- OpenAPI: `https://www.txtclaw.com/openapi.yaml`
- MCP server: `pnpm -s dlx txtclaw-mcp@latest`

Related:

- `https://skills.sh`
- `https://docs.openclaw.ai/tools/skills`
- `https://clawhub.ai`

## If You Already Use OpenClaw

You can ask OpenClaw to set this up for you:

1. Create a TXT CLAW API key: `https://www.txtclaw.com/dashboard/api-keys`
2. Paste `https://www.txtclaw.com/quickstart.md` and `https://www.txtclaw.com/openapi.yaml` into your agent
3. Ask it to create an agent and send a test message

## MCP Config Snippet

This snippet is intended to be copy/pasted into MCP-compatible clients:

```json
{
  "mcpServers": {
    "txtclaw": {
      "command": "pnpm",
      "args": ["-s", "dlx", "txtclaw-mcp@latest"],
      "env": {
        "TXTCLAW_API_BASE_URL": "https://txtclaw-sms-e2e.lopez731.workers.dev",
        "TXTCLAW_API_KEY": "vck_REPLACE_ME"
      }
    }
  }
}
```

Notes:

- `-s` keeps `pnpm dlx` quiet so it won’t corrupt MCP stdio output.

## Tools Provided

- `txtclaw_status`
- `txtclaw_create_agent`
- `txtclaw_get_agent`
- `txtclaw_send_message`
- `txtclaw_byok_get`
- `txtclaw_byok_set`
- `txtclaw_byok_clear`
