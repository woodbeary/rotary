import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft, BookOpen, Rocket } from "lucide-react"

export const metadata: Metadata = {
  title: "API Reference — TXT CLAW",
  description:
    "TXT CLAW developer API docs (preview). Agent-friendly quickstart + OpenAPI.",
}

export default function ApiReferencePage() {
  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <Link
          href="/"
          className="mb-10 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <div className="rounded-2xl border border-border/60 bg-card p-8 md:p-10">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-border bg-muted/50 px-3 py-1 text-xs text-muted-foreground">
            <BookOpen className="h-3.5 w-3.5" />
            Developer API (Preview)
          </div>

          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            TXT CLAW API
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            Create a dedicated OpenClaw agent and talk to it over HTTPS.
            SMS provisioning is a separate lane and may be async.
          </p>

          <div className="mt-6 space-y-3 rounded-xl border border-border/60 bg-muted/20 p-5">
            <h2 className="text-lg font-semibold text-foreground">
              Quickstart (1 line)
            </h2>
            <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
              {`pnpm dlx txtclaw@latest init`}
            </pre>
            <p className="text-sm text-muted-foreground">
              Agent-friendly docs:
              {" "}
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
          </div>

          <div className="mt-6 space-y-4 rounded-xl border border-border/60 bg-muted/20 p-5">
            <h2 className="text-lg font-semibold text-foreground">
              HTTP (curl)
            </h2>
            <p className="text-sm text-muted-foreground">
              Create an agent:
            </p>
            <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "system_prompt": "You are a helpful assistant. Keep replies concise.",
    "sms": { "mode": "none" }
  }'`}
            </pre>

            <p className="text-sm text-muted-foreground">
              Send a message:
            </p>
            <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \\
  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "text": "Draft a polite text asking my landlord to fix a leak." }'`}
            </pre>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-border/60 bg-muted/20 p-4">
              <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                JS Example
              </p>
                <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`const baseUrl =
  process.env.TXTCLAW_API_BASE_URL ?? "https://txtclaw-sms-e2e.lopez731.workers.dev"
const apiKey = process.env.TXTCLAW_API_KEY

const create = await fetch(\`\${baseUrl}/v1/agents\`, {
  method: "POST",
  headers: {
    Authorization: \`Bearer \${apiKey}\`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    system_prompt: "You are a helpful assistant. Keep replies concise.",
    sms: { mode: "none" },
  }),
})
const { agent_id } = await create.json()

const msg = await fetch(\`\${baseUrl}/v1/agents/\${agent_id}/messages\`, {
  method: "POST",
  headers: {
    Authorization: \`Bearer \${apiKey}\`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({ text: "Summarize this: ..." }),
})
console.log(await msg.json())`}
              </pre>
            </div>
            <div className="rounded-xl border border-border/60 bg-muted/20 p-4">
              <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Notes
              </p>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>
                  Runtime API works immediately (no Twilio required).
                </li>
                <li>
                  SMS provisioning is preview/async; response may be{" "}
                  <span className="font-mono text-foreground">
                    needs_compliance
                  </span>
                  .
                </li>
                <li>
                  Every response includes{" "}
                  <span className="font-mono text-foreground">trace_id</span>{" "}
                  (and header{" "}
                  <span className="font-mono text-foreground">
                    x-txtclaw-trace-id
                  </span>
                  ).
                </li>
                <li>
                  If you get{" "}
                  <span className="font-mono text-foreground">429</span>, respect{" "}
                  <span className="font-mono text-foreground">Retry-After</span>.
                </li>
                <li>
                  Stable agent ingest docs:{" "}
                  <a
                    className="font-mono text-foreground underline underline-offset-4"
                    href="/agents.md"
                  >
                    /agents.md
                  </a>
                </li>
              </ul>
            </div>
          </div>

          <p className="mt-8 text-sm text-muted-foreground">
            API access is in private preview. For access, contact us.
          </p>
        </div>
      </div>
    </main>
  )
}
