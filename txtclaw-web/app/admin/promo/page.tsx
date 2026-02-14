import Link from "next/link"
import { auth } from "@clerk/nextjs/server"
import { ArrowLeft } from "lucide-react"
import { notFound } from "next/navigation"
import { redirect } from "next/navigation"
import { AdminPromoGenerator } from "@/components/admin-promo-generator"
import {
  canUserGeneratePromoCodes,
  getPromoCampaignId,
  getPromoGrantCents,
} from "@/lib/promo-config"
import { CLERK_ENABLED } from "@/lib/clerk-config"

export const dynamic = "force-dynamic"

export default async function AdminPromoPage() {
  if (!CLERK_ENABLED) {
    return (
      <main className="min-h-screen bg-background">
        <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <h1 className="text-2xl font-semibold text-foreground">Admin promo</h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Clerk auth is not configured in this environment.
            </p>
          </div>
        </div>
      </main>
    )
  }

  const { userId } = await auth()
  const isAdmin = canUserGeneratePromoCodes(userId)

  if (!userId) {
    redirect("/sign-in?redirect_url=/admin/promo")
  }
  if (!isAdmin) notFound()

  const campaignId = getPromoCampaignId()
  const grantCents = getPromoGrantCents()

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

        <AdminPromoGenerator campaignId={campaignId} grantCents={grantCents} />
      </div>
    </main>
  )
}
