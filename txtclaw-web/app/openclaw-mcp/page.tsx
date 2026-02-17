import { Footer } from "@/components/footer"
import { Navbar } from "@/components/navbar"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "OpenClaw MCP — TXT CLAW",
  description:
    "Agent-friendly docs plus an MCP integration lane (preview). Start with the TXT CLAW HTTP API today, and add MCP tooling as it rolls out.",
  alternates: {
    canonical: "/openclaw-mcp",
  },
}

export default function OpenClawMcpPage() {
  return (
    <div className="min-h-screen">
      <Navbar />
      <main className="mx-auto max-w-4xl px-6 py-16 md:py-24">
        <div className="space-y-10">
          <header className="space-y-4">
            <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
              SEO: OpenClaw MCP
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              OpenClaw MCP (Preview)
            </h1>
            <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
              TXT CLAW is a wrappable agent runtime API built on OpenClaw. MCP support is an
              optional lane for coding agents that want tools and structured operations, but you can
              start today with the HTTP API.
            </p>
          </header>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">
              Start With Agent-Friendly Docs
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              If you are pasting a URL into Cursor/Codex, use:
            </p>
            <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
              <li>
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/agents.md"
                >
                  /agents.md
                </a>
              </li>
              <li>
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/openapi.yaml"
                >
                  /openapi.yaml
                </a>
              </li>
            </ul>
          </section>

          <section className="rounded-2xl border border-border/60 bg-card p-6 md:p-8">
            <h2 className="text-lg font-semibold text-foreground">What MCP Will Add</h2>
            <p className="mt-2 text-sm text-muted-foreground">
              MCP is planned for operational workflows (logs, traces, and automation). The HTTP API
              stays the source of truth.
            </p>
            <p className="mt-4 text-sm text-muted-foreground">
              For the developer entry point, start at{" "}
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
      </main>
      <Footer />
    </div>
  )
}
