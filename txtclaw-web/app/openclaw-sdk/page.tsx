import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "OpenClaw SDK (Node/JS) — TXT CLAW",
  description:
    "TXT CLAW ships a tiny Node/JavaScript SDK for an OpenClaw-powered agent runtime API. Create an agent, send messages over HTTPS, and optionally add SMS later.",
  alternates: {
    canonical: "/openclaw-sdk",
  },
}

export default function OpenClawSdkPage() {
  return (
    <DevDocsShell title="SDK">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            SEO: OpenClaw SDK
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            OpenClaw SDK (Node/JavaScript)
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            TXT CLAW provides a tiny JS client for the developer API so you can wrap
            OpenClaw-powered agents into your own product quickly.
          </p>
        </header>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Quickstart</h2>
          <div className="mt-4">
            <CodeBlock
              title="1 line"
              language="bash"
              code={`pnpm i txtclaw`}
              copyLabel="Copy"
            />
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            Agent docs:{" "}
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
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">SDK Example</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Published as the <span className="font-mono text-foreground">txtclaw</span> package.
          </p>
          <div className="mt-4 space-y-3">
            <CodeBlock title="Install" language="bash" code={`pnpm i txtclaw`} copyLabel="Copy" />
            <CodeBlock
              title="Usage"
              language="ts"
              code={`import { createTxtclawClient } from \"txtclaw\"\n\nconst client = createTxtclawClient({\n  apiKey: process.env.TXTCLAW_API_KEY,\n  baseUrl: process.env.TXTCLAW_API_BASE_URL, // optional\n})\n\nconst { agent_id } = await client.createAgent({\n  systemPrompt: \"You are a helpful assistant. Keep replies concise.\",\n})\n\nconst { reply_text } = await client.sendMessage(agent_id, {\n  text: \"Draft a polite text asking my landlord to fix a leak.\",\n})\n\nconsole.log(reply_text)`}
              copyLabel="Copy"
            />
          </div>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Links</h2>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              Developers overview:{" "}
              <Link
                href="/developers"
                className="font-mono text-foreground underline underline-offset-4"
              >
                /developers
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
            <li>
              API reference:{" "}
              <Link
                href="/api-reference"
                className="font-mono text-foreground underline underline-offset-4"
              >
                /api-reference
              </Link>
            </li>
          </ul>
        </section>
      </div>
    </DevDocsShell>
  )
}
