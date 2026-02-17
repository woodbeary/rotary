import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import { getPublicApiBaseUrl } from "@/lib/txtclaw-urls"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "OpenClaw MCP — TXT CLAW",
  description:
    "Agent-friendly docs plus an MCP integration lane (preview). Start with the TXT CLAW HTTP API, and optionally add MCP tooling for structured operations.",
  alternates: {
    canonical: "/openclaw-mcp",
  },
}

export default function OpenClawMcpPage() {
  const apiBaseUrl = getPublicApiBaseUrl()

  return (
    <DevDocsShell title="MCP">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            SEO: OpenClaw MCP
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            OpenClaw MCP (Preview)
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            TXT CLAW is a wrappable agent runtime API built on OpenClaw. MCP is an optional lane for
            coding agents that want tools and structured operations, but you can start today with
            the HTTP API.
          </p>
        </header>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Start With Docs</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Paste URLs into Cursor/Codex. Start with:
          </p>
          <div className="mt-4">
            <CodeBlock
              title="Pasteable URLs"
              language="text"
              wrap
              code={`https://www.txtclaw.com/quickstart.md\nhttps://www.txtclaw.com/agents.md\nhttps://www.txtclaw.com/openapi.yaml\nhttps://www.txtclaw.com/mcp.md`}
              copyLabel="Copy URLs"
            />
          </div>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">What MCP Adds</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            MCP is for operational workflows (tools, traces, automation). The HTTP API stays the
            source of truth.
          </p>
          <div className="mt-5 space-y-3">
            <CodeBlock
              title="Run the MCP server"
              language="bash"
              code={`pnpm -s dlx txtclaw-mcp@latest`}
              copyLabel="Copy"
            />
            <CodeBlock
              title="Cursor/Codex config (example)"
              language="json"
              code={`{\n  \"mcpServers\": {\n    \"txtclaw\": {\n      \"command\": \"pnpm\",\n      \"args\": [\"-s\", \"dlx\", \"txtclaw-mcp@latest\"],\n      \"env\": {\n        \"TXTCLAW_API_BASE_URL\": \"${apiBaseUrl}\",\n        \"TXTCLAW_API_KEY\": \"vck_REPLACE_ME\"\n      }\n    }\n  }\n}`}
              copyLabel="Copy"
            />
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Start at{" "}
            <Link
              href="/developers"
              className="font-mono text-foreground underline underline-offset-4"
            >
              /developers
            </Link>
            .
          </p>
        </section>
      </div>
    </DevDocsShell>
  )
}
