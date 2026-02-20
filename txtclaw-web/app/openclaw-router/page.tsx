import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "OpenClaw Router — TXT CLAW",
  description:
    "Hosted routing with fallback models + optional BYOK, designed for wrappers. Predictable semantics, trace IDs, and stable Markdown/OpenAPI docs.",
}

export default function OpenClawRouterPage() {
  return (
    <DevDocsShell title="Router">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            OpenClaw Router
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Hosted routing, with BYOK escape hatch.
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            TXT CLAW supports two inference lanes: a hosted router (primary + fallback model) and an
            optional BYOK lane (encrypted). This lets you ship a reliable default while keeping
            dependency risk low for serious devs.
          </p>
        </header>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">What you get</h2>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            <li>Hosted router: fast default model, optional fallback on upstream failure.</li>
            <li>Traceability: every response includes `trace_id` + `x-txtclaw-trace-id`.</li>
            <li>Stable docs endpoints for bots: `*.md` + OpenAPI.</li>
            <li>BYOK: store provider keys encrypted and apply them to your agents.</li>
          </ul>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Docs</h2>
          <p className="mt-2 text-sm text-muted-foreground">Paste these into Cursor/Codex:</p>
          <p className="mt-4 text-sm">
            <a className="font-mono underline underline-offset-4" href="/developers/docs/routing">
              /routing.md
            </a>
            {" · "}
            <a className="font-mono underline underline-offset-4" href="/developers/docs/byok">
              /byok.md
            </a>
            {" · "}
            <a className="font-mono underline underline-offset-4" href="/developers/docs/openapi">
              /openapi.yaml
            </a>
          </p>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Start in 60 seconds</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Activate Dev API, generate an API key, then use the CLI doctor to prove it works
            end-to-end:
          </p>
          <div className="mt-4">
            <CodeBlock
              title="Commands"
              language="bash"
              code={`pnpm dlx txtclaw@latest init\npnpm dlx txtclaw@latest doctor`}
              copyLabel="Copy"
            />
          </div>
          <p className="mt-4 text-sm">
            <Link className="font-mono underline underline-offset-4" href="/dashboard/billing">
              /dashboard/billing
            </Link>
            {" · "}
            <Link className="font-mono underline underline-offset-4" href="/dashboard/api-keys">
              /dashboard/api-keys
            </Link>
          </p>
        </section>
      </div>
    </DevDocsShell>
  )
}
