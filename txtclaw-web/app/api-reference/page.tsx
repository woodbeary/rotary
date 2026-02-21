import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import { BookOpen, Rocket } from "lucide-react"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "API Reference — TXT CLAW",
  description: "TXT CLAW developer API docs (preview). Agent-friendly quickstart + OpenAPI.",
}

export default function ApiReferencePage() {
  return (
    <DevDocsShell title="API Reference">
      <div className="space-y-8">
        <div className="inline-flex items-center gap-2 rounded-full border border-border bg-muted/50 px-3 py-1 text-xs text-muted-foreground">
          <BookOpen className="h-3.5 w-3.5" />
          Developer API (Preview)
        </div>

        <header className="space-y-3">
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            TXT CLAW API
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            Create a dedicated OpenClaw agent and talk to it over HTTPS. SMS provisioning is a
            separate lane and may be async.
          </p>
        </header>

        <section className="grid grid-cols-1 gap-4 lg:grid-cols-12">
          <div className="lg:col-span-7 space-y-4">
            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h2 className="text-lg font-semibold text-foreground">Quickstart</h2>
                  <p className="mt-1 text-sm text-muted-foreground">
                    Start with the CLI, then fall back to curl. (Always use pnpm.)
                  </p>
                </div>
                <Rocket className="h-5 w-5 text-muted-foreground" />
              </div>
              <div className="mt-4">
                <CodeBlock
                  title="1 line"
                  language="bash"
                  code={`pnpm i txtclaw`}
                  copyLabel="Copy"
                />
              </div>
              <p className="mt-4 text-sm text-muted-foreground">
                Agent-friendly docs:{" "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/developers/docs/agents"
                >
                  /agents.md
                </a>
                {" · "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/developers/docs/openapi"
                >
                  /openapi.yaml
                </a>
              </p>
            </div>

            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <h2 className="text-lg font-semibold text-foreground">HTTP (curl)</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                Create an agent, then send a message.
              </p>
              <div className="mt-4 space-y-3">
                <CodeBlock
                  title="Create agent"
                  language="bash"
                  code={`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \\\n  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d '{\n    \"system_prompt\": \"You are a helpful assistant. Keep replies concise.\",\n    \"sms\": { \"mode\": \"none\" }\n  }'`}
                  copyLabel="Copy"
                />
                <CodeBlock
                  title="Send message"
                  language="bash"
                  code={`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \\\n  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d '{ \"text\": \"Draft a polite text asking my landlord to fix a leak.\" }'`}
                  copyLabel="Copy"
                />
              </div>
            </div>
          </div>

          <aside className="lg:col-span-5 space-y-4">
            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                JS example
              </div>
              <div className="mt-3">
                <CodeBlock
                  title="Fetch wrapper"
                  language="ts"
                  code={`const baseUrl =\n  process.env.TXTCLAW_API_BASE_URL ?? \"https://txtclaw-sms-e2e.lopez731.workers.dev\"\nconst apiKey = process.env.TXTCLAW_API_KEY\n\nconst create = await fetch(baseUrl + \"/v1/agents\", {\n  method: \"POST\",\n  headers: {\n    Authorization: \"Bearer \" + apiKey,\n    \"Content-Type\": \"application/json\",\n  },\n  body: JSON.stringify({\n    system_prompt: \"You are a helpful assistant. Keep replies concise.\",\n    sms: { mode: \"none\" },\n  }),\n})\nconst { agent_id } = await create.json()\n\nconst msg = await fetch(baseUrl + \"/v1/agents/\" + agent_id + \"/messages\", {\n  method: \"POST\",\n  headers: {\n    Authorization: \"Bearer \" + apiKey,\n    \"Content-Type\": \"application/json\",\n  },\n  body: JSON.stringify({ text: \"Summarize this: ...\" }),\n})\nconsole.log(await msg.json())`}
                  copyLabel="Copy"
                />
              </div>
            </div>

            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Notes
              </div>
              <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
                <li>Runtime API works immediately (no Twilio required).</li>
                <li>
                  SMS provisioning is preview/async; response may be{" "}
                  <span className="font-mono text-foreground">needs_compliance</span>.
                </li>
                <li>
                  Every response includes{" "}
                  <span className="font-mono text-foreground">trace_id</span> (and header{" "}
                  <span className="font-mono text-foreground">x-txtclaw-trace-id</span>).
                </li>
                <li>
                  If you get <span className="font-mono text-foreground">429</span>, respect{" "}
                  <span className="font-mono text-foreground">Retry-After</span>.
                </li>
              </ul>
              <p className="mt-4 text-sm text-muted-foreground">
                Activate Dev API in{" "}
                <Link
                  href="/dashboard/billing"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /dashboard/billing
                </Link>
                , then generate an API key in{" "}
                <Link
                  href="/dashboard/api-keys"
                  className="font-mono text-foreground underline underline-offset-4"
                >
                  /dashboard/api-keys
                </Link>
                .
              </p>
            </div>
          </aside>
        </section>
      </div>
    </DevDocsShell>
  )
}
