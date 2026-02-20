import { CodeBlock } from "@/components/code-block"
import { DevDocsShell } from "@/components/dev-docs-shell"
import { DeveloperCopyPrompt } from "@/components/developer-copy-prompt"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { getPublicApiBaseUrl } from "@/lib/txtclaw-urls"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "Developers — TXT CLAW",
  description:
    "Set up OpenClaw agents via API. TXT CLAW developer docs: agent-friendly Markdown + OpenAPI. Create an agent and talk to it over HTTPS. SMS is an optional lane.",
}

export default function DevelopersPage() {
  const apiBaseUrl = getPublicApiBaseUrl()

  return (
    <DevDocsShell title="Developers">
      <div className="space-y-10">
        <header className="space-y-4">
          <div className="inline-flex items-center rounded-full border border-border/70 bg-muted/30 px-3 py-1 font-mono text-[11px] text-muted-foreground">
            Developer Docs (Preview)
          </div>
          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            TXT CLAW for Developers
          </h1>
          <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">
            Create a dedicated OpenClaw agent (memory + configuration) and talk to it over HTTPS.
            SMS provisioning is a separate, optional lane.
          </p>
        </header>

        <section className="grid grid-cols-1 gap-4 lg:grid-cols-12">
          <div className="lg:col-span-7">
            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <div className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Quickstart
              </div>
              <h2 className="mt-1 text-lg font-semibold text-foreground">3 steps, no surprises</h2>
              <p className="mt-1 text-sm text-muted-foreground">
                This is designed to be real: you should get a reply and a trace id within minutes.
              </p>

              <div className="mt-5 space-y-4">
                <div className="rounded-xl border border-border/60 bg-background p-4">
                  <div className="font-mono text-[11px] text-muted-foreground">Step 1</div>
                  <div className="mt-1 text-sm font-medium text-foreground">
                    Activate + generate
                  </div>
                  <div className="mt-1 text-sm text-muted-foreground">
                    {CLERK_ENABLED ? (
                      <>
                        First activate Dev API in{" "}
                        <Link
                          href="/dashboard/billing"
                          className="font-mono text-foreground underline underline-offset-4"
                        >
                          /dashboard/billing
                        </Link>
                        , then open{" "}
                        <Link
                          href="/dashboard/api-keys"
                          className="font-mono text-foreground underline underline-offset-4"
                        >
                          /dashboard/api-keys
                        </Link>{" "}
                        and click “Generate key”.
                      </>
                    ) : (
                      <>Dashboard requires Clerk auth (not configured here).</>
                    )}
                  </div>
                </div>

                <div className="rounded-xl border border-border/60 bg-background p-4">
                  <div className="font-mono text-[11px] text-muted-foreground">Step 2</div>
                  <div className="mt-1 text-sm font-medium text-foreground">Initialize</div>
                  <div className="mt-3">
                    <CodeBlock
                      title="Install + init"
                      language="bash"
                      code={`pnpm dlx txtclaw@latest init`}
                      copyLabel="Copy"
                    />
                  </div>
                </div>

                <div className="rounded-xl border border-border/60 bg-background p-4">
                  <div className="font-mono text-[11px] text-muted-foreground">Step 3</div>
                  <div className="mt-1 text-sm font-medium text-foreground">Verify end-to-end</div>
                  <div className="mt-3">
                    <CodeBlock
                      title="Doctor"
                      language="bash"
                      code={`pnpm dlx txtclaw@latest doctor`}
                      copyLabel="Copy"
                    />
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-6">
              <DeveloperCopyPrompt />
            </div>
          </div>

          <aside className="lg:col-span-5 space-y-4">
            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <h2 className="text-lg font-semibold text-foreground">HTTP API</h2>
              <p className="mt-2 text-sm text-muted-foreground">
                Base URL: <span className="break-all font-mono text-foreground">{apiBaseUrl}</span>
              </p>
              <div className="mt-4 space-y-3">
                <CodeBlock
                  title="Env vars"
                  language="bash"
                  code={`export TXTCLAW_API_BASE_URL="${apiBaseUrl}"\nexport TXTCLAW_API_KEY="vck_REPLACE_ME"`}
                  copyLabel="Copy"
                />
                <CodeBlock
                  title="Create an agent"
                  language="bash"
                  code={`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents" \\\n  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d '{ \"system_prompt\": \"You are a helpful assistant.\", \"sms\": { \"mode\": \"none\" } }'`}
                  copyLabel="Copy"
                />
                <CodeBlock
                  title="Send a message"
                  language="bash"
                  code={`curl -sS "$TXTCLAW_API_BASE_URL/v1/agents/$AGENT_ID/messages" \\\n  -H "Authorization: Bearer $TXTCLAW_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d '{ \"text\": \"Draft a polite text asking my landlord to fix a leak.\" }'`}
                  copyLabel="Copy"
                />
              </div>
            </div>

            <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
              <h2 className="text-lg font-semibold text-foreground">Pasteable Docs Links</h2>
              <p className="mt-2 text-sm text-muted-foreground">
                If you’re pasting URLs into Cursor/Codex, start with{" "}
                <a
                  className="font-mono text-foreground underline underline-offset-4"
                  href="/quickstart.md"
                >
                  /quickstart.md
                </a>
                .
              </p>
              <div className="mt-4">
                <CodeBlock
                  title="Docs URLs"
                  language="text"
                  wrap
                  code={`https://www.txtclaw.com/quickstart.md\nhttps://www.txtclaw.com/agents.md\nhttps://www.txtclaw.com/openapi.yaml\nhttps://www.txtclaw.com/pricing.md\nhttps://www.txtclaw.com/api-keys.md\nhttps://www.txtclaw.com/cli.md\nhttps://www.txtclaw.com/mcp.md\nhttps://www.txtclaw.com/skills.md\nhttps://www.txtclaw.com/byok.md\nhttps://www.txtclaw.com/routing.md\nhttps://www.txtclaw.com/rate-limits.md\nhttps://www.txtclaw.com/security.md`}
                  copyLabel="Copy URLs"
                />
              </div>
            </div>
          </aside>
        </section>
      </div>
    </DevDocsShell>
  )
}
