import { getUserPrivateMetadata } from "@/lib/billing"
import { verifyPromoCode } from "@/lib/promo-codes"
import { getPromoCampaignId, getPromoGrantCents, isPromoRedeemEnabled } from "@/lib/promo-config"
import {
  applyPromotionGrant,
  getCampaignClaimCodeId,
  getPromotionsMetadata,
  hasCodeBeenRedeemed,
} from "@/lib/promo-metadata"
import { type User, auth, clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000

type RedeemPayload = {
  code?: string
}

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

export async function POST(request: NextRequest) {
  if (!isPromoRedeemEnabled()) {
    return jsonError("Promo code redemption is currently disabled. Try again later.", 503)
  }

  const { userId } = await auth()
  if (!userId) {
    return jsonError("Authentication required.", 401)
  }

  const promoCodeSecret = process.env.PROMO_CODE_SECRET?.trim()
  if (!promoCodeSecret) {
    return jsonError("Promo redemption is not configured. Missing PROMO_CODE_SECRET.", 500)
  }

  const campaignId = getPromoCampaignId()
  const grantCents = getPromoGrantCents()

  let payload: RedeemPayload
  try {
    payload = (await request.json()) as RedeemPayload
  } catch {
    return jsonError("Invalid JSON body.", 400)
  }

  const verification = verifyPromoCode({
    code: payload.code,
    campaignId,
    amountCents: grantCents,
    secret: promoCodeSecret,
  })

  if (!verification.ok) {
    return jsonError(toInvalidCodeError(verification.reason), 400)
  }

  try {
    const client = await clerkClient()
    const user = await client.users.getUser(userId)
    const currentPromotions = getPromotionsMetadata(user)
    const campaignClaimCodeId = getCampaignClaimCodeId(currentPromotions, campaignId)

    if (campaignClaimCodeId && campaignClaimCodeId !== verification.codeId) {
      return jsonError("This account already redeemed a code for this campaign.", 409)
    }

    if (
      campaignClaimCodeId === verification.codeId ||
      hasCodeBeenRedeemed(currentPromotions, verification.codeId)
    ) {
      return NextResponse.json(
        {
          ok: true,
          applied: false,
          idempotent: true,
          campaignId,
          codeId: verification.codeId,
          grantCents,
          totalGrantedCents: currentPromotions.totalGrantedCents,
          balanceCents: currentPromotions.balanceCents,
          message: "Code already redeemed on this account.",
        },
        { status: 200 },
      )
    }

    const users = await listUsersForPromoScan(client)
    const matchedUser = findRedeemingUserByCodeId(users, verification.codeId)

    if (matchedUser && matchedUser.id !== userId) {
      return jsonError("This code has already been redeemed.", 409)
    }

    if (matchedUser && matchedUser.id === userId) {
      return NextResponse.json(
        {
          ok: true,
          applied: false,
          idempotent: true,
          campaignId,
          codeId: verification.codeId,
          grantCents,
          totalGrantedCents: currentPromotions.totalGrantedCents,
          balanceCents: currentPromotions.balanceCents,
          message: "Code already redeemed on this account.",
        },
        { status: 200 },
      )
    }

    const grant = applyPromotionGrant({
      promotions: currentPromotions,
      campaignId,
      codeId: verification.codeId,
      amountCents: grantCents,
    })

    if (grant.idempotent) {
      return NextResponse.json(
        {
          ok: true,
          applied: false,
          idempotent: true,
          campaignId,
          codeId: verification.codeId,
          grantCents,
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
        applied: true,
        idempotent: false,
        campaignId,
        codeId: verification.codeId,
        grantCents,
        totalGrantedCents: grant.promotions.totalGrantedCents,
        balanceCents: grant.promotions.balanceCents,
        message: "Code redeemed successfully.",
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
