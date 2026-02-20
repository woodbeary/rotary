"use client"

import { CodeBlock } from "@/components/code-block"
import { CopyButton } from "@/components/copy-button"
import { Button } from "@/components/ui/button"
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible"
import { getPublicApiBaseUrl } from "@/lib/txtclaw-urls"
import { cn } from "@/lib/utils"
import { ChevronDown } from "lucide-react"
import { useMemo } from "react"
import { toast } from "sonner"

export function DeveloperCopyPrompt() {
  const prompt = useMemo(() => {
    const apiBaseUrl = getPublicApiBaseUrl()

    return [
      "# Add TXT CLAW (OpenClaw agent runtime API)",
      "",
      "**Purpose:** Set up OpenClaw agents via API (create agents, send messages, get replies).",
      "**Guardrails:** Use pnpm. Never log or commit API keys. Keep keys server-side only.",
      "",
      "## 1) Create account + activate + API key",
      "- Sign up: https://www.txtclaw.com/sign-up",
      "- Activate Dev API (subscription or promo): https://www.txtclaw.com/dashboard/billing",
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
    <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
      <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div className="min-w-0">
          <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
            For coding agents
          </div>
          <h2 className="mt-1 text-lg font-semibold text-foreground">
            Copy a setup prompt (Clerk-style)
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Paste into Codex/Cursor so it installs the SDK/CLI correctly and follows the guardrails.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <CopyButton text={prompt} label="Copy prompt" variant="secondary" />
          <Button variant="outline" asChild>
            <a href="/developers/docs/quickstart">Open quickstart</a>
          </Button>
        </div>
      </div>

      <Collapsible>
        <div className="mt-4 flex items-center justify-between">
          <div className="text-sm font-medium text-foreground">Prompt contents</div>
          <CollapsibleTrigger asChild>
            <Button variant="ghost" size="sm" className="gap-2">
              <span>Show</span>
              <ChevronDown className={cn("h-4 w-4")} />
            </Button>
          </CollapsibleTrigger>
        </div>
        <CollapsibleContent className="mt-3">
          <CodeBlock
            code={prompt}
            title="TXT CLAW setup prompt"
            language="Markdown"
            wrap
            copyLabel="Copy prompt"
          />
        </CollapsibleContent>
      </Collapsible>
    </section>
  )
}
