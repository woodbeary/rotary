import { Footer } from "@/components/footer"
import { Navbar } from "@/components/navbar"
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
    <div className="min-h-screen">
      <Navbar />
      <main className="mx-auto max-w-4xl px-6 py-16 md:py-24">
        <div className="space-y-10">
          <header className="space-y-4">
            <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
              SEO: OpenClaw API
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              OpenClaw API
            </h1>
            <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
              TXT CLAW exposes a developer API for OpenClaw-powered agents. You create an agent,
              send messages over HTTPS, and get back plain text. SMS provisioning is a separate,
              optional lane.
            </p>
          </header>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">Quickstart (1 line)</h2>
            <pre className="mt-3 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
              {`pnpm dlx txtclaw@latest init`}
            </pre>
            <p className="mt-3 text-sm text-muted-foreground">
              Docs for coding agents:{" "}
              <a
                className="font-mono text-foreground underline underline-offset-4"
                href="/agents.md"
              >
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

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">Minimal API Flow</h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Base URL: <span className="break-all font-mono text-foreground">{apiBaseUrl}</span>
            </p>

            <div className="mt-5 space-y-4">
              <div>
                <p className="text-sm text-muted-foreground">Get a TXT CLAW API key:</p>
                <p className="mt-2 text-sm">
                  <Link
                    href="/dashboard/api-keys"
                    className="font-mono text-foreground underline underline-offset-4"
                  >
                    /dashboard/api-keys
                  </Link>
                </p>
              </div>

              <div>
                <p className="text-sm text-muted-foreground">Create an agent:</p>
                <pre className="mt-2 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
                  {`curl -sS "${apiBaseUrl}/v1/agents" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "system_prompt": "You are a helpful assistant.", "sms": { "mode": "none" } }'`}
                </pre>
              </div>

              <div>
                <p className="text-sm text-muted-foreground">Send a message:</p>
                <pre className="mt-2 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
                  {`curl -sS "${apiBaseUrl}/v1/agents/$AGENT_ID/messages" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "text": "Write a short reply to this email: ..." }'`}
                </pre>
              </div>
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

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">FAQ</h2>
            <div className="mt-4 space-y-4 text-sm text-muted-foreground">
              <div>
                <p className="font-medium text-foreground">Is this the official OpenClaw API?</p>
                <p className="mt-1">
                  TXT CLAW is built on OpenClaw and exposes a developer runtime API for
                  OpenClaw-powered agents. If you want the base project, see{" "}
                  <a
                    className="text-foreground underline underline-offset-4"
                    href="https://openclaw.com"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    openclaw.com
                  </a>
                  .
                </p>
              </div>

              <div>
                <p className="font-medium text-foreground">Do I need Twilio to use the API?</p>
                <p className="mt-1">
                  No. The runtime API works without Twilio. SMS provisioning is optional and may
                  require compliance steps.
                </p>
              </div>

              <div>
                <p className="font-medium text-foreground">Can I wrap this into my own product?</p>
                <p className="mt-1">
                  Yes. The design goal is &quot;wrappable&quot;: a clean agent runtime API + stable
                  docs for coding agents.
                </p>
              </div>

              <div>
                <p className="font-medium text-foreground">
                  How do I set up OpenClaw agents via API?
                </p>
                <p className="mt-1">
                  Start at{" "}
                  <a
                    className="font-mono text-foreground underline underline-offset-4"
                    href="/quickstart.md"
                  >
                    /quickstart.md
                  </a>{" "}
                  (it’s designed to be pasted into coding agents), then follow the minimal flow
                  above.
                </p>
              </div>
            </div>
          </section>
        </div>
      </main>
      <Footer />
    </div>
  )
}
