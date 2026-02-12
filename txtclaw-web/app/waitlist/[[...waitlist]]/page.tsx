import Link from "next/link"
import type { Metadata } from "next"
import { ArrowLeft, MessageCircle, ShieldCheck } from "lucide-react"
import {
  CLERK_DISABLED_FOR_LOCAL_LIVE_KEY,
  CLERK_ENABLED,
} from "@/lib/clerk-config"
import { WaitlistSignUp } from "@/components/waitlist-signup"

export const metadata: Metadata = {
  title: "Waitlist — TXT CLAW",
  description:
    "Join the TXT CLAW Apple beta waitlist for invite-only access.",
}

export const dynamic = "force-dynamic"

export default async function WaitlistPage() {
  const clerkEnabled = CLERK_ENABLED

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

        <div className="space-y-6">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-amber-500/40 bg-amber-500/10 px-3 py-1 text-xs font-medium text-amber-300">
              <MessageCircle className="h-3.5 w-3.5" />
              <ShieldCheck className="h-3.5 w-3.5" />
              Apple beta · invite required
            </div>
            <h1 className="text-balance font-mono text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              Join the Apple Beta Waitlist
            </h1>
            <p className="mt-4 text-base leading-relaxed text-muted-foreground">
              TXT CLAW is invite-only during Apple beta. Use the same email address as your Apple ID / iCloud account so we can match your invite correctly when you&apos;re approved.
            </p>

            <div className="mt-8 space-y-4 rounded-xl border border-border/60 bg-muted/20 p-5 text-sm text-foreground/90">
              <p>What to expect:</p>
              <ul className="list-disc space-y-2 pl-5 text-muted-foreground">
                <li>Invite-only access in staged batches</li>
                <li>Apple ID email matching to avoid invite mismatch</li>
                <li>Private beta while we harden reliability and support</li>
                <li>Feedback priority for early members</li>
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
                  {CLERK_DISABLED_FOR_LOCAL_LIVE_KEY
                    ? "Local development is using a live Clerk key scoped to the production domain. Use a Clerk test key locally, or run from an allowed production domain/subdomain."
                    : "Add your Clerk publishable key to enable signup on this page: `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`."}
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  )
}
