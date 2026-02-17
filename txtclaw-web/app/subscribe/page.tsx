import { SubscribePanel } from "@/components/subscribe-panel"
import { getUserBetaState, getUserOfferCode } from "@/lib/billing"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { getPromotionsMetadata } from "@/lib/promo-metadata"
import { auth, clerkClient } from "@clerk/nextjs/server"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

export const dynamic = "force-dynamic"

export default async function SubscribePage() {
  if (!CLERK_ENABLED) {
    return (
      <main className="min-h-screen bg-background">
        <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <h1 className="text-2xl font-semibold text-foreground">Subscribe</h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Clerk auth is not configured in this environment.
            </p>
            <Link
              href="/waitlist"
              className="mt-6 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              Back to waitlist
            </Link>
          </div>
        </div>
      </main>
    )
  }

  const { userId } = await auth()

  if (!userId) {
    return (
      <main className="min-h-screen bg-background">
        <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <h1 className="text-2xl font-semibold text-foreground">Sign in required</h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Use your invite link to sign in, then return here to complete payment.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link
                href="/sign-in"
                className="inline-flex items-center gap-2 rounded-md border border-border bg-background px-4 py-2 text-sm text-foreground hover:bg-accent"
              >
                Sign in
              </Link>
              <Link
                href="/waitlist"
                className="inline-flex items-center gap-2 rounded-md border border-border px-4 py-2 text-sm text-foreground hover:bg-accent"
              >
                Join waitlist
              </Link>
              <Link
                href="/"
                className="inline-flex items-center gap-2 rounded-md border border-border px-4 py-2 text-sm text-foreground hover:bg-accent"
              >
                Back home
              </Link>
            </div>
          </div>
        </div>
      </main>
    )
  }

  const client = await clerkClient()
  const user = await client.users.getUser(userId)

  const primaryEmail =
    (
      user as unknown as {
        primaryEmailAddress?: { emailAddress?: string | null } | null
        emailAddresses?: Array<{ emailAddress?: string | null }> | null
      }
    ).primaryEmailAddress?.emailAddress ||
    (
      user as unknown as {
        emailAddresses?: Array<{ emailAddress?: string | null }> | null
      }
    ).emailAddresses?.[0]?.emailAddress ||
    undefined

  const betaState = getUserBetaState(user)
  const offerCode = getUserOfferCode(user)
  const promotions = getPromotionsMetadata(user)

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-4xl px-6 py-12 md:py-20">
        <Link
          href="/"
          className="mb-8 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <SubscribePanel
          email={primaryEmail}
          betaState={betaState}
          offerCode={offerCode}
          promoBalanceCents={promotions.balanceCents}
          promoTotalGrantedCents={promotions.totalGrantedCents}
        />
      </div>
    </main>
  )
}
