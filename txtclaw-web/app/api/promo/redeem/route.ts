import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  requireVerifiedUserId,
} from "@/app/api/console/_shared"
import { getUserPrivateMetadata } from "@/lib/billing"
import {
  applyBillingCostCodeRedemption,
  getBillingCostCampaignClaimCodeId,
  getBillingCostPromoMetadata,
  hasBillingCostCodeBeenRedeemed,
} from "@/lib/billing-cost-promo-metadata"
import {
  applyDevApiCodeRedemption,
  getDevApiCampaignClaimCodeId,
  getDevApiPromoMetadata,
  hasDevApiCodeBeenRedeemed,
} from "@/lib/dev-api-promo-metadata"
import { verifyPromoCode } from "@/lib/promo-codes"
import {
  getBillingCostPromoCampaignId,
  getBillingCostPromoCents,
  getDevApiPromoCampaignId,
  getDevApiPromoPlan,
  getDevApiPromoSignatureCents,
  getPromoCampaignId,
  getPromoGrantCents,
  isBillingCostPromoEnabled,
  isDevApiPromoEnabled,
  isPromoRedeemEnabled,
} from "@/lib/promo-config"
import {
  applyPromotionGrant,
  getCampaignClaimCodeId,
  getPromotionsMetadata,
  hasCodeBeenRedeemed,
} from "@/lib/promo-metadata"
import { type User, clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000

type RedeemPayload = {
  code?: string
}

type PromoMatch =
  | { kind: "credits"; campaignId: string; codeId: string; grantCents: number }
  | {
      kind: "billing_cost"
      campaignId: string
      codeId: string
      costCents: number
    }
  | {
      kind: "dev_api_plan"
      campaignId: string
      codeId: string
      signatureCents: number
      plan: "pro" | "max" | "byok"
    }

type VerifyPromoCodeAnyResult =
  | { ok: true; match: PromoMatch }
  | { ok: false; reason: "invalid_format" | "signature_mismatch" }

async function listUsersForPromoScan(
  client: Awaited<ReturnType<typeof clerkClient>>,
): Promise<User[]> {
  const users: User[] = []
  let offset = 0

  while (offset < LIST_USERS_MAX) {
    const page = await client.users.getUserList({
      limit: LIST_USERS_PAGE_SIZE,
      offset,
      orderBy: "+created_at",
    })

    const batch = page.data || []
    users.push(...batch)
    if (batch.length < LIST_USERS_PAGE_SIZE) break
    offset += batch.length
  }

  return users
}

function findRedeemingUserByCodeId(users: User[], codeId: string): User | undefined {
  return users.find((candidate) => {
    const promotions = getPromotionsMetadata(candidate)
    return hasCodeBeenRedeemed(promotions, codeId)
  })
}

function toInvalidCodeError(reason: "invalid_format" | "signature_mismatch"): string {
  if (reason === "invalid_format") return "Invalid code format."
  return "Invalid code."
}

function jsonError(message: string, status: number) {
  return NextResponse.json(
    {
      ok: false,
      error: message,
    },
    { status },
  )
}

function verifyPromoCodeAny(args: {
  code: unknown
  secret: string
}): VerifyPromoCodeAnyResult {
  // 1) Credit codes (existing behavior).
  const creditsCampaignId = getPromoCampaignId()
  const creditsGrantCents = getPromoGrantCents()
  const credits = verifyPromoCode({
    code: args.code,
    campaignId: creditsCampaignId,
    amountCents: creditsGrantCents,
    secret: args.secret,
  })
  if (credits.ok) {
    return {
      ok: true,
      match: {
        kind: "credits",
        campaignId: creditsCampaignId,
        codeId: credits.codeId,
        grantCents: creditsGrantCents,
      },
    }
  }

  // 2) Dev API plan codes (optional feature gate).
  if (isDevApiPromoEnabled()) {
    const plan = getDevApiPromoPlan()
    if (plan !== "free") {
      const devApiCampaignId = getDevApiPromoCampaignId()
      const signatureCents = getDevApiPromoSignatureCents()
      const planVerification = verifyPromoCode({
        code: args.code,
        campaignId: devApiCampaignId,
        amountCents: signatureCents,
        secret: args.secret,
      })
      if (planVerification.ok) {
        return {
          ok: true,
          match: {
            kind: "dev_api_plan",
            campaignId: devApiCampaignId,
            codeId: planVerification.codeId,
            signatureCents,
            plan,
          },
        }
      }
    }
  }

  // 3) Billing cost codes (cost-only checkout).
  if (isBillingCostPromoEnabled()) {
    const costCents = getBillingCostPromoCents()
    if (costCents > 0) {
      const costCampaignId = getBillingCostPromoCampaignId()
      const verification = verifyPromoCode({
        code: args.code,
        campaignId: costCampaignId,
        amountCents: costCents,
        secret: args.secret,
      })
      if (verification.ok) {
        return {
          ok: true,
          match: {
            kind: "billing_cost",
            campaignId: costCampaignId,
            codeId: verification.codeId,
            costCents,
          },
        }
      }
    }
  }

  // Prefer surfacing format errors when possible.
  return { ok: false, reason: credits.reason }
}

async function setWorkerPlan(args: {
  userId: string
  plan: "pro" | "max" | "byok"
  offerCode: string
  paidAt?: string
}): Promise<{ ok: true } | { ok: false; error: string }> {
  const token = getConsoleServiceToken()
  if (!token) return { ok: false, error: "Missing TXTCLAW_CONSOLE_SERVICE_TOKEN." }

  const baseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${baseUrl}/console/v1/plan`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: args.userId,
      plan: args.plan,
      provider: "manual",
      offer_code: args.offerCode,
      paid_at: args.paidAt,
    }),
  })

  const text = await res.text().catch(() => "")
  if (!res.ok) {
    return { ok: false, error: `Worker plan update failed (${res.status}): ${text}` }
  }

  try {
    const json = text ? (JSON.parse(text) as any) : null
    if (!json?.ok) {
      return { ok: false, error: `Worker plan update rejected: ${text || "invalid JSON"}` }
    }
  } catch {
    return { ok: false, error: `Worker plan update returned invalid JSON.` }
  }

  return { ok: true }
}

export async function POST(request: NextRequest) {
  if (!isPromoRedeemEnabled()) {
    return jsonError("Promo code redemption is currently disabled. Try again later.", 503)
  }

  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified.response
  const userId = verified.userId

  const promoCodeSecret = process.env.PROMO_CODE_SECRET?.trim()
  if (!promoCodeSecret) {
    return jsonError("Promo redemption is not configured. Missing PROMO_CODE_SECRET.", 500)
  }

  let payload: RedeemPayload
  try {
    payload = (await request.json()) as RedeemPayload
  } catch {
    return jsonError("Invalid JSON body.", 400)
  }

  const verification = verifyPromoCodeAny({
    code: payload.code,
    secret: promoCodeSecret,
  })

  if (!verification.ok) return jsonError(toInvalidCodeError(verification.reason), 400)
  const match = verification.match

  try {
    const client = await clerkClient()
    const user = await client.users.getUser(userId)
    if (match.kind === "credits") {
      const currentPromotions = getPromotionsMetadata(user)
      const campaignClaimCodeId = getCampaignClaimCodeId(currentPromotions, match.campaignId)

      if (campaignClaimCodeId && campaignClaimCodeId !== match.codeId) {
        return jsonError("This account already redeemed a code for this campaign.", 409)
      }

      if (
        campaignClaimCodeId === match.codeId ||
        hasCodeBeenRedeemed(currentPromotions, match.codeId)
      ) {
        return NextResponse.json(
          {
            ok: true,
            kind: "credits",
            applied: false,
            idempotent: true,
            campaignId: match.campaignId,
            codeId: match.codeId,
            grantCents: match.grantCents,
            totalGrantedCents: currentPromotions.totalGrantedCents,
            balanceCents: currentPromotions.balanceCents,
            message: "Code already redeemed on this account.",
          },
          { status: 200 },
        )
      }

      const users = await listUsersForPromoScan(client)
      const matchedUser = findRedeemingUserByCodeId(users, match.codeId)

      if (matchedUser && matchedUser.id !== userId) {
        return jsonError("This code has already been redeemed.", 409)
      }

      if (matchedUser && matchedUser.id === userId) {
        return NextResponse.json(
          {
            ok: true,
            kind: "credits",
            applied: false,
            idempotent: true,
            campaignId: match.campaignId,
            codeId: match.codeId,
            grantCents: match.grantCents,
            totalGrantedCents: currentPromotions.totalGrantedCents,
            balanceCents: currentPromotions.balanceCents,
            message: "Code already redeemed on this account.",
          },
          { status: 200 },
        )
      }

      const grant = applyPromotionGrant({
        promotions: currentPromotions,
        campaignId: match.campaignId,
        codeId: match.codeId,
        amountCents: match.grantCents,
      })

      if (grant.idempotent) {
        return NextResponse.json(
          {
            ok: true,
            kind: "credits",
            applied: false,
            idempotent: true,
            campaignId: match.campaignId,
            codeId: match.codeId,
            grantCents: match.grantCents,
            totalGrantedCents: grant.promotions.totalGrantedCents,
            balanceCents: grant.promotions.balanceCents,
            message: "Code already redeemed on this account.",
          },
          { status: 200 },
        )
      }

      const privateMetadata = getUserPrivateMetadata(user)
      await client.users.updateUserMetadata(userId, {
        privateMetadata: {
          ...privateMetadata,
          promotions: grant.promotions,
        },
      })

      return NextResponse.json(
        {
          ok: true,
          kind: "credits",
          applied: true,
          idempotent: false,
          campaignId: match.campaignId,
          codeId: match.codeId,
          grantCents: match.grantCents,
          totalGrantedCents: grant.promotions.totalGrantedCents,
          balanceCents: grant.promotions.balanceCents,
          message: "Code redeemed successfully.",
        },
        { status: 200 },
      )
    }

    if (match.kind === "billing_cost") {
      const currentPromos = getBillingCostPromoMetadata(user)
      const campaignClaimCodeId = getBillingCostCampaignClaimCodeId(currentPromos, match.campaignId)

      if (campaignClaimCodeId && campaignClaimCodeId !== match.codeId) {
        return jsonError(
          "This account already redeemed a billing cost code for this campaign.",
          409,
        )
      }

      const users = await listUsersForPromoScan(client)
      const matchedUser = users.find((candidate) => {
        const promos = getBillingCostPromoMetadata(candidate)
        return hasBillingCostCodeBeenRedeemed(promos, match.codeId)
      })
      if (matchedUser && matchedUser.id !== userId) {
        return jsonError("This code has already been redeemed.", 409)
      }

      const applied = applyBillingCostCodeRedemption({
        promos: currentPromos,
        campaignId: match.campaignId,
        codeId: match.codeId,
      })

      const privateMetadata = getUserPrivateMetadata(user)
      const currentBilling = (privateMetadata.billing as Record<string, unknown> | undefined) || {}
      const now = new Date()
      const expiresAt = new Date(now.getTime() + 72 * 60 * 60 * 1000).toISOString()

      await client.users.updateUserMetadata(userId, {
        privateMetadata: {
          ...privateMetadata,
          billingCostPromos: applied.promos,
          billing: {
            ...currentBilling,
            checkoutOfferOverride: "PROMO_CODE_REDACTED",
            checkoutOfferOverrideCodeId: match.codeId,
            checkoutOfferOverrideSetAt: now.toISOString(),
            checkoutOfferOverrideExpiresAt: expiresAt,
          },
        },
      })

      return NextResponse.json(
        {
          ok: true,
          kind: "billing_cost",
          applied: !applied.idempotent,
          idempotent: applied.idempotent,
          campaignId: match.campaignId,
          codeId: match.codeId,
          costCents: match.costCents,
          message:
            "Cost checkout unlocked. Continue to /dashboard/billing and click Upgrade (monthly).",
        },
        { status: 200 },
      )
    }

    // Dev API plan promo: claim code in Clerk metadata, then set Worker plan.
    const currentDevApiPromos = getDevApiPromoMetadata(user)
    const campaignClaimCodeId = getDevApiCampaignClaimCodeId(currentDevApiPromos, match.campaignId)

    if (campaignClaimCodeId && campaignClaimCodeId !== match.codeId) {
      return jsonError("This account already redeemed a Dev API code for this campaign.", 409)
    }

    // Global single-use check (launch scale): scan Clerk users for already-redeemed code ids.
    const users = await listUsersForPromoScan(client)
    const matchedUser = users.find((candidate) => {
      const promos = getDevApiPromoMetadata(candidate)
      return hasDevApiCodeBeenRedeemed(promos, match.codeId)
    })
    if (matchedUser && matchedUser.id !== userId) {
      return jsonError("This code has already been redeemed.", 409)
    }

    const applied = applyDevApiCodeRedemption({
      promos: currentDevApiPromos,
      campaignId: match.campaignId,
      codeId: match.codeId,
    })

    const privateMetadata = getUserPrivateMetadata(user)
    await client.users.updateUserMetadata(userId, {
      privateMetadata: {
        ...privateMetadata,
        devApiPromos: applied.promos,
      },
    })

    const now = new Date().toISOString()
    const worker = await setWorkerPlan({
      userId,
      plan: match.plan,
      offerCode: `promo:${match.campaignId}:${match.codeId}`,
      paidAt: now,
    })

    if (!worker.ok) {
      return jsonError(worker.error, 502)
    }

    return NextResponse.json(
      {
        ok: true,
        kind: "dev_api_plan",
        applied: !applied.idempotent,
        idempotent: applied.idempotent,
        campaignId: match.campaignId,
        codeId: match.codeId,
        plan: match.plan,
        message: `Dev API plan updated: ${match.plan.toUpperCase()}.`,
      },
      { status: 200 },
    )
  } catch (error) {
    return jsonError(
      error instanceof Error ? error.message : "Unable to redeem code right now.",
      500,
    )
  }
}
