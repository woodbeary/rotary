import Link from "next/link"
import type { Metadata } from "next"
import { CheckCircle2, Clock3 } from "lucide-react"

export const metadata: Metadata = {
  title: "Payment confirmed — TXT CLAW",
  description:
    "Payment confirmed. Your Apple beta invite instructions are on the way.",
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
            Apple invite in progress
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            We received your payment. You&apos;ll receive Apple invite instructions
            shortly.
          </p>

          <div className="mt-8 rounded-xl border border-border/60 bg-muted/20 p-5 text-sm">
            <p className="flex items-center gap-2 font-medium text-foreground">
              <Clock3 className="h-4 w-4" />
              Expected timing
            </p>
            <p className="mt-2 text-muted-foreground">
              Usually within 24h. You&apos;ll receive your Apple invite instructions,
              then chat directly in the same thread.
            </p>
          </div>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              href="/subscribe"
              className="inline-flex items-center rounded-md border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            >
              Billing status
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
