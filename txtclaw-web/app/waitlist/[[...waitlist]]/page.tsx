import Link from "next/link"
import type { Metadata } from "next"
import { ArrowLeft, Sparkles } from "lucide-react"
import { WaitlistSignUp } from "@/components/waitlist-signup"

export const metadata: Metadata = {
  title: "Waitlist — TXT CLAW",
  description:
    "Join the TXT CLAW waitlist and claim your handle for private beta access.",
}

export const dynamic = "force-dynamic"

export default async function WaitlistPage() {
  const clerkEnabled = Boolean(process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY)

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-5xl px-6 py-16 md:py-24">
        <Link
          href="/"
          className="mb-10 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <div className="grid gap-8 lg:grid-cols-[1.05fr_1fr] lg:items-start">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-amber-500/40 bg-amber-500/10 px-3 py-1 text-xs font-medium text-amber-300">
              <Sparkles className="h-3.5 w-3.5" />
              Private Beta Waitlist
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              Join the API Waitlist
            </h1>
            <p className="mt-4 text-base leading-relaxed text-muted-foreground">
              We are onboarding early design partners for TXT CLAW API access.
              Sign up to claim your `@handle` and get private beta invites.
            </p>

            <div className="mt-8 space-y-4 rounded-xl border border-border/60 bg-muted/20 p-5 text-sm text-foreground/90">
              <p>What to expect:</p>
              <ul className="list-disc space-y-2 pl-5 text-muted-foreground">
                <li>Reserve your `@handle` before public launch</li>
                <li>Early access to `POST /api/v1/agent/provision`</li>
                <li>Priority feedback loop on endpoint design</li>
                <li>Migration guidance from prototype to production</li>
              </ul>
            </div>
          </div>

          <div className="rounded-2xl border border-border/60 bg-card p-5 md:p-6">
            {clerkEnabled ? (
              <WaitlistSignUp />
            ) : (
              <div className="rounded-xl border border-border/60 bg-muted/20 p-5">
                <p className="text-sm font-medium text-foreground">
                  Waitlist is being configured.
                </p>
                <p className="mt-2 text-sm text-muted-foreground">
                  Add your Clerk publishable key to enable signup on this page:
                  `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  )
}
