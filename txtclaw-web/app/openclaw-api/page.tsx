import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "OpenClaw API — TXT CLAW",
  description:
    "Set up OpenClaw agents via API. TXT CLAW is an OpenClaw-powered agent runtime API you can wrap: create agents, send messages over HTTPS, and optionally add SMS later.",
  alternates: {
    canonical: "/openclaw-api",
  },
}

const DEFAULT_BASE_URL = "https://txtclaw-sms-e2e.lopez731.workers.dev"

export default function OpenClawApiPage() {
  const apiBaseUrl =
    String(process.env.NEXT_PUBLIC_TXTCLAW_API_BASE_URL || "").trim() || DEFAULT_BASE_URL

  return (
    <DevDocsShell title="OpenClaw API">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            SEO: OpenClaw API
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            OpenClaw API
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            TXT CLAW exposes a developer API for OpenClaw-powered agents. You create an agent, send
            messages over HTTPS, and get back plain text. SMS provisioning is a separate, optional
            lane.
          </p>
        </header>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Quickstart</h2>
          <div className="mt-4">
            <CodeBlock
              title="1 line"
              language="bash"
              code={`pnpm dlx txtclaw@latest init`}
              copyLabel="Copy"
            />
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Docs for coding agents:{" "}
            <a className="font-mono text-foreground underline underline-offset-4" href="/agents.md">
              /agents.md
            </a>
            {" · "}
            <a
              className="font-mono text-foreground underline underline-offset-4"
              href="/openapi.yaml"
            >
              /openapi.yaml
            </a>
          </p>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Minimal API Flow</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Base URL: <span className="break-all font-mono text-foreground">{apiBaseUrl}</span>
          </p>

          <div className="mt-5 space-y-3">
            <p className="text-sm text-muted-foreground">
              Get a TXT CLAW API key:{" "}
              <Link
                href="/dashboard/api-keys"
                className="font-mono text-foreground underline underline-offset-4"
              >
                /dashboard/api-keys
              </Link>
            </p>

            <CodeBlock
              title="Create agent"
              language="bash"
              code={`curl -sS \"${apiBaseUrl}/v1/agents\" \\\n  -H \"Authorization: Bearer $TXTCLAW_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{ \"system_prompt\": \"You are a helpful assistant.\", \"sms\": { \"mode\": \"none\" } }'`}
              copyLabel="Copy"
            />
            <CodeBlock
              title="Send message"
              language="bash"
              code={`curl -sS \"${apiBaseUrl}/v1/agents/$AGENT_ID/messages\" \\\n  -H \"Authorization: Bearer $TXTCLAW_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{ \"text\": \"Write a short reply to this email: ...\" }'`}
              copyLabel="Copy"
            />
          </div>

          <p className="mt-5 text-sm text-muted-foreground">
            For the full spec, see{" "}
            <a
              className="font-mono text-foreground underline underline-offset-4"
              href="/openapi.yaml"
            >
              /openapi.yaml
            </a>{" "}
            or the{" "}
            <Link
              href="/api-reference"
              className="font-mono text-foreground underline underline-offset-4"
            >
              /api-reference
            </Link>{" "}
            page.
          </p>
        </section>
      </div>
    </DevDocsShell>
  )
}
