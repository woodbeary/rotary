import type { Metadata } from "next"
import Link from "next/link"
import { Navbar } from "@/components/navbar"
import { Footer } from "@/components/footer"

export const metadata: Metadata = {
  title: "Developers — TXT CLAW",
  description:
    "TXT CLAW developer docs: agent-friendly Markdown + OpenAPI. Create an OpenClaw agent and talk to it over HTTPS. SMS is an optional lane.",
}

const DEFAULT_BASE_URL = "https://txtclaw-sms-e2e.lopez731.workers.dev"

export default function DevelopersPage() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main className="mx-auto max-w-4xl px-6 py-16 md:py-24">
        <div className="space-y-10">
          <header className="space-y-4">
            <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
              Developer Docs (Preview)
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              TXT CLAW for Developers
            </h1>
            <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
              Create a dedicated OpenClaw agent (memory + tools) and talk to it
              over HTTPS. SMS provisioning is a separate, optional lane.
            </p>
          </header>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">
              Quickstart (1 line)
            </h2>
            <pre className="mt-3 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
              {`pnpm dlx txtclaw@latest init`}
            </pre>
            <p className="mt-3 text-sm text-muted-foreground">
              Stable agent-ingest docs:{" "}
              <a
                className="font-mono text-foreground underline underline-offset-4"
                href="/agents.md"
              >
                /agents.md
              </a>{" "}
              {" · "}
              <a
                className="font-mono text-foreground underline underline-offset-4"
                href="/openapi.yaml"
              >
                /openapi.yaml
              </a>
            </p>
          </section>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">HTTP API</h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Base URL (preview today):{" "}
              <span className="font-mono text-foreground">{DEFAULT_BASE_URL}</span>
            </p>

            <div className="mt-5 space-y-4">
              <div>
                <p className="text-sm text-muted-foreground">Set env vars:</p>
                <pre className="mt-2 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`export TXTCLAW_API_BASE_URL="${DEFAULT_BASE_URL}"
export TXTCLAW_API_KEY="REPLACE_ME"`}
                </pre>
              </div>

              <div>
                <p className="text-sm text-muted-foreground">
                  Create an agent:
                </p>
                <pre className="mt-2 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "system_prompt": "You are a helpful assistant.", "sms": { "mode": "none" } }'`}
                </pre>
              </div>

              <div>
                <p className="text-sm text-muted-foreground">Send a message:</p>
                <pre className="mt-2 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "text": "Draft a polite text asking my landlord to fix a leak." }'`}
                </pre>
              </div>
            </div>

            <p className="mt-5 text-sm text-muted-foreground">
              API keys are in private preview. If you want access, use the
              contact link on the homepage or DM us on X.
            </p>
          </section>

          <section className="grid gap-4 md:grid-cols-2">
            <div className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
              <h2 className="text-lg font-semibold text-foreground">
                OpenClaw API
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">
                Looking for an &quot;OpenClaw API&quot;? Start here.
              </p>
              <p className="mt-4 text-sm">
                <Link
                  href="/openclaw-api"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /openclaw-api
                </Link>
              </p>
            </div>

            <div className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
              <h2 className="text-lg font-semibold text-foreground">
                SMS Agent API
              </h2>
              <p className="mt-2 text-sm text-muted-foreground">
                SMS provisioning is optional and may require compliance steps.
              </p>
              <p className="mt-4 text-sm">
                <Link
                  href="/sms-agent-api"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /sms-agent-api
                </Link>
              </p>
            </div>
          </section>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">More</h2>
            <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
              <li>
                OpenClaw MCP:{" "}
                <Link
                  href="/openclaw-mcp"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /openclaw-mcp
                </Link>
              </li>
              <li>
                OpenClaw SDK:{" "}
                <Link
                  href="/openclaw-sdk"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /openclaw-sdk
                </Link>
              </li>
              <li>
                API reference:{" "}
                <Link
                  href="/api-reference"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /api-reference
                </Link>
              </li>
              <li>
                Agent-friendly Markdown:{" "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/agents.md"
                >
                  /agents.md
                </a>
              </li>
              <li>
                OpenAPI spec:{" "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/openapi.yaml"
                >
                  /openapi.yaml
                </a>
              </li>
            </ul>
          </section>
        </div>
      </main>
      <Footer />
    </div>
  )
}
