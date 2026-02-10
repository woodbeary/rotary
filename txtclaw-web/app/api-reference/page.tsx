import type { Metadata } from "next"
import Link from "next/link"
import { ArrowLeft, BookOpen, Rocket } from "lucide-react"
import { WaitlistModalButton } from "@/components/waitlist-modal-button"

export const metadata: Metadata = {
  title: "API Reference — TXT CLAW",
  description:
    "TXT CLAW API docs. Endpoint reference and private beta access.",
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
            API Reference
          </div>

          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            API Docs
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            Public API is not live yet. Initial endpoint docs and integration
            guidance are in progress.
          </p>

          <div className="mt-6 inline-flex items-center gap-1.5 rounded-md border border-border bg-muted px-3 py-1.5 text-xs font-medium text-foreground">
            <Rocket className="h-3.5 w-3.5" />
            Coming soon
          </div>

          <div className="mt-8 space-y-4 rounded-xl border border-border/60 bg-muted/20 p-5">
            <h2 className="text-lg font-semibold text-foreground">
              Planned Endpoint
            </h2>
            <p className="font-mono text-sm text-foreground">
              POST /api/v1/agent/provision
            </p>
            <p className="text-sm text-muted-foreground">
              Provision a dedicated AI assistant with a phone number and custom
              system prompt.
            </p>
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-border/60 bg-muted/20 p-4">
              <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Request Example
              </p>
              <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`{
  "system_prompt": "You are a concierge assistant for Acme Dental.",
  "customer_ref": "cust_92af4d",
  "payment_method_token": "pm_tok_abc123"
}`}
              </pre>
            </div>
            <div className="rounded-xl border border-border/60 bg-muted/20 p-4">
              <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                Response Example
              </p>
              <pre className="overflow-x-auto rounded-md border border-border/60 bg-background p-3 text-xs text-foreground">
{`{
  "agent_id": "agt_01J9QG2D63X",
  "phone_number": "+1 573-555-0142",
  "status": "provisioning",
  "created_at": "2026-02-09T18:34:22Z"
}`}
              </pre>
            </div>
          </div>

          <WaitlistModalButton
            className="mt-8"
            variant="outline"
            source="api_reference"
          />
        </div>
      </div>
    </main>
  )
}
