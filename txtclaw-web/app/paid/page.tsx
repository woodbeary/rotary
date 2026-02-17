import { CheckCircle2, Clock3 } from "lucide-react"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "Payment confirmed — TXT CLAW",
  description: "Payment confirmed. Your TXT CLAW Dev API limits will update shortly.",
}

export default function PaidPage() {
  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <div className="rounded-2xl border border-border/60 bg-card p-8 md:p-10">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-emerald-500/40 bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-200">
            <CheckCircle2 className="h-3.5 w-3.5" />
            Payment confirmed
          </div>

          <h1 className="text-balance text-3xl font-semibold tracking-tight text-foreground md:text-4xl">
            Limits upgrading
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            We received your payment. Your Dev API plan caps (RPM + daily caps) will update shortly.
          </p>

          <div className="mt-8 rounded-xl border border-border/60 bg-muted/20 p-5 text-sm">
            <p className="flex items-center gap-2 font-medium text-foreground">
              <Clock3 className="h-4 w-4" />
              Expected timing
            </p>
            <p className="mt-2 text-muted-foreground">
              Usually within a minute. If your limits don&apos;t update, refresh{" "}
              <span className="font-mono text-foreground">/dashboard/billing</span>.
            </p>
          </div>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/dashboard/billing"
              className="inline-flex items-center rounded-md border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            >
              Billing
            </Link>
            <Link
              href="/"
              className="inline-flex items-center rounded-md border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            >
              Back home
            </Link>
          </div>
        </div>
      </div>
    </main>
  )
}
