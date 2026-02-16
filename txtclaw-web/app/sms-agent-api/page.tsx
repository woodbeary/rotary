import type { Metadata } from "next"
import Link from "next/link"
import { Navbar } from "@/components/navbar"
import { Footer } from "@/components/footer"

export const metadata: Metadata = {
  title: "SMS Agent API — TXT CLAW",
  description:
    "An SMS-first agent API lane (preview). Start with the runtime API over HTTPS, then add managed SMS provisioning when ready.",
  alternates: {
    canonical: "/sms-agent-api",
  },
}

export default function SmsAgentApiPage() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main className="mx-auto max-w-4xl px-6 py-16 md:py-24">
        <div className="space-y-10">
          <header className="space-y-4">
            <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
              SEO: SMS Agent API
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              SMS Agent API (Preview)
            </h1>
            <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
              TXT CLAW is an agent runtime API you can optionally connect to SMS.
              The runtime works immediately over HTTPS; managed SMS provisioning
              is a separate lane and may require compliance steps.
            </p>
          </header>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">
              Start With Runtime (No Twilio Required)
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              See{" "}
              <Link
                href="/developers"
                className="font-mono text-foreground underline underline-offset-4"
              >
                /developers
              </Link>{" "}
              or the agent-ingest docs at{" "}
              <a
                className="font-mono text-foreground underline underline-offset-4"
                href="/agents.md"
              >
                /agents.md
              </a>
              .
            </p>
          </section>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">
              SMS Provisioning (Scaffold)
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              The API includes an endpoint so SDK/docs stay coherent even before
              managed SMS is fully productized.
            </p>
            <pre className="mt-4 overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/channels/sms" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "mode": "managed" }'`}
            </pre>
            <p className="mt-3 text-sm text-muted-foreground">
              Responses today may be{" "}
              <span className="font-mono text-foreground">needs_compliance</span>{" "}
              /{" "}
              <span className="font-mono text-foreground">needs_setup</span>{" "}
              /{" "}
              <span className="font-mono text-foreground">disabled</span>{" "}
              depending on mode.
            </p>
          </section>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">Links</h2>
            <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
              <li>
                OpenAPI:{" "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/openapi.yaml"
                >
                  /openapi.yaml
                </a>
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
                OpenClaw API overview:{" "}
                <Link
                  href="/openclaw-api"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /openclaw-api
                </Link>
              </li>
            </ul>
          </section>
        </div>
      </main>
      <Footer />
    </div>
  )
}

