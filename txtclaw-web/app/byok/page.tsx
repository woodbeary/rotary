import { DevDocsShell } from "@/components/dev-docs-shell"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "BYOK — TXT CLAW",
  description:
    "Bring your own model key (OpenAI/Anthropic/OpenAI-compatible) to TXT CLAW. Keys are stored encrypted and used only for your traffic.",
}

export default function ByokPage() {
  return (
    <DevDocsShell title="BYOK">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            OpenClaw BYOK
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Bring your own key.
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            If hosted inference costs are limiting your wrapper app, configure BYOK once per TXT
            CLAW API key and run agents using your own provider key.
          </p>
        </header>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">How it works</h2>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            <li>1. Generate a TXT CLAW API key.</li>
            <li>2. Call `PUT /v1/byok` once to store your provider key encrypted.</li>
            <li>3. Create agents with `llm.mode=\"byok\"`.</li>
          </ul>

          <div className="mt-5 space-y-3">
            <p className="text-sm text-muted-foreground">Docs (agent-friendly Markdown):</p>
            <p className="text-sm">
              <a className="font-mono underline underline-offset-4" href="/byok.md">
                /byok.md
              </a>
              {" · "}
              <a className="font-mono underline underline-offset-4" href="/security.md">
                /security.md
              </a>
              {" · "}
              <a className="font-mono underline underline-offset-4" href="/routing.md">
                /routing.md
              </a>
            </p>
          </div>
        </section>

        <section className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
          <h2 className="text-lg font-semibold text-foreground">Get started</h2>
          <p className="mt-2 text-sm text-muted-foreground">
            Create an API key and configure BYOK in the console:
          </p>
          <p className="mt-4 text-sm">
            <Link className="font-mono underline underline-offset-4" href="/dashboard/api-keys">
              /dashboard/api-keys
            </Link>
          </p>
          <p className="mt-4 text-xs text-muted-foreground">
            BYOK keys are stored encrypted and are never shown again after saving.
          </p>
        </section>
      </div>
    </DevDocsShell>
  )
}
