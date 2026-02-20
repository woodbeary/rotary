import { AdminBillingCostPromoGenerator } from "@/components/admin-billing-cost-promo-generator"
import { AdminDevApiPromoGenerator } from "@/components/admin-dev-api-promo-generator"
import { AdminPromoGenerator } from "@/components/admin-promo-generator"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import {
  canUserGeneratePromoCodes,
  getBillingCostPromoCampaignId,
  getBillingCostPromoCents,
  getDevApiPromoCampaignId,
  getDevApiPromoPlan,
  getDevApiPromoSignatureCents,
  getPromoCampaignId,
  getPromoGrantCents,
  isBillingCostPromoEnabled,
  isDevApiPromoEnabled,
} from "@/lib/promo-config"
import { auth } from "@clerk/nextjs/server"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"
import { notFound } from "next/navigation"
import { redirect } from "next/navigation"

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

        <div className="grid gap-6">
          <AdminPromoGenerator campaignId={campaignId} grantCents={grantCents} />
          {isDevApiPromoEnabled() && getDevApiPromoPlan() !== "free" ? (
            <AdminDevApiPromoGenerator
              campaignId={getDevApiPromoCampaignId()}
              signatureCents={getDevApiPromoSignatureCents()}
              plan={getDevApiPromoPlan()}
            />
          ) : null}
          {isBillingCostPromoEnabled() && getBillingCostPromoCents() > 0 ? (
            <AdminBillingCostPromoGenerator
              campaignId={getBillingCostPromoCampaignId()}
              costCents={getBillingCostPromoCents()}
            />
          ) : null}
        </div>
      </div>
    </main>
  )
}
