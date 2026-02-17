import { WaitlistSuccessFlag } from "@/components/waitlist-success-flag"
import { ArrowRight, CheckCircle2 } from "lucide-react"
import type { Metadata } from "next"
import Link from "next/link"

export const metadata: Metadata = {
  title: "You're on the waitlist — TXT CLAW",
  description: "Waitlist signup complete. Next steps for TXT CLAW Apple beta access.",
}

export default function WaitlistSuccessPage() {
  return (
    <main className="min-h-screen bg-background">
      <WaitlistSuccessFlag />
      <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
        <div className="rounded-2xl border border-border/60 bg-card p-8 md:p-10">
          <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-emerald-500/40 bg-emerald-500/10 px-3 py-1 text-xs font-medium text-emerald-300">
            <CheckCircle2 className="h-3.5 w-3.5" />
            Waitlist confirmed
          </div>

          <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            You&apos;re on the list
          </h1>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">
            You&apos;re on the Apple beta waitlist. We&apos;ll send updates as new invite batches
            open.
          </p>

          <div className="mt-8 space-y-3 rounded-xl border border-border/60 bg-muted/20 p-5 text-sm">
            <p className="font-medium text-foreground">What happens next:</p>
            <p className="text-muted-foreground">
              1) Your waitlist signup is confirmed for the next invite batch.
            </p>
            <p className="text-muted-foreground">
              2) We send invite instructions to your waitlist email.
            </p>
            <p className="text-muted-foreground">
              3) You activate and begin chatting in the Apple beta thread.
            </p>
          </div>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Link
              href="/api-reference"
              className="inline-flex items-center rounded-md border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            >
              View API Docs
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
            <Link
              href="/"
              className="inline-flex items-center rounded-md border border-border px-4 py-2 text-sm font-medium text-foreground transition-colors hover:bg-accent"
            >
              Back to home
            </Link>
          </div>
        </div>
      </div>
    </main>
  )
}
