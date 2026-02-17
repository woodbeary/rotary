"use client"

import { Button } from "@/components/ui/button"
import { useMemo } from "react"
import { toast } from "sonner"

export function DeveloperCopyPrompt() {
  const prompt = useMemo(() => {
    const apiBaseUrl =
      String(process.env.NEXT_PUBLIC_TXTCLAW_API_BASE_URL || "").trim() ||
      "https://txtclaw-sms-e2e.lopez731.workers.dev"

    return [
      "# Add TXT CLAW (OpenClaw agent runtime API)",
      "",
      "**Purpose:** Set up OpenClaw agents via API (create agents, send messages, get replies).",
      "**Guardrails:** Use pnpm. Never log or commit API keys. Keep keys server-side only.",
      "",
      "## 1) Create account + API key",
      "- Sign up: https://www.txtclaw.com/sign-up",
      "- API key dashboard: https://www.txtclaw.com/dashboard/api-keys",
      "- Keys look like: vck_...",
      "",
      "## 2) Set env vars (server-side)",
      `export TXTCLAW_API_BASE_URL="${apiBaseUrl}"`,
      'export TXTCLAW_API_KEY="vck_REPLACE_ME"',
      "",
      "## 3) Verify",
      'curl -sS "$TXTCLAW_API_BASE_URL/v1/status" -H "Authorization: Bearer $TXTCLAW_API_KEY"',
      "",
      "## 4) Create agent + send message",
      "- POST /v1/agents",
      "- POST /v1/agents/{agent_id}/messages",
      "",
      "## Optional: BYOK",
      "- PUT /v1/byok (store provider key encrypted)",
      '- Create agents with: llm: { "mode": "byok" }',
      "",
      "## Pasteable docs",
      "- https://www.txtclaw.com/quickstart.md",
      "- https://www.txtclaw.com/agents.md",
      "- https://www.txtclaw.com/openapi.yaml",
      "- https://www.txtclaw.com/byok.md",
      "- https://www.txtclaw.com/routing.md",
    ].join("\n")
  }, [])

  async function copy() {
    try {
      await navigator.clipboard.writeText(prompt)
      toast.success("Copied prompt.")
    } catch {
      toast.error("Clipboard copy failed on this device.")
    }
  }

  return (
    <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">Copy Prompt (For Coding Agents)</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Paste this into Codex/Cursor when someone asks “how do I set up OpenClaw agents via
            API?”
          </p>
        </div>
        <Button variant="secondary" onClick={copy}>
          Copy prompt
        </Button>
      </div>
      <pre className="mt-4 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground whitespace-pre-wrap">
        {prompt}
      </pre>
    </section>
  )
}
