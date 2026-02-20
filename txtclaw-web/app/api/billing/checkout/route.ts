import {
  type OfferCode,
  collectLaunchStats,
  getBillingMetadata,
  getUserPrivateMetadata,
  mergeBetaState,
  mergeBillingMetadata,
  mergeSquareMetadata,
  parseOfferType,
  resolveCheckoutOffer,
} from "@/lib/billing"
import { getBillingCostPromoCents } from "@/lib/promo-config"
import {
  createSquareCheckoutLink,
  encodeSquareMetadataToken,
  resolveSquareEnvironment,
} from "@/lib/square"
import { type User, auth, clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000

type CheckoutPayload = {
  offerType?: "monthly" | "ltd"
}

function getRequestOrigin(request: NextRequest): string {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL?.trim()
  if (appUrl) {
    return appUrl.startsWith("http://") || appUrl.startsWith("https://")
      ? appUrl.replace(/\/$/, "")
      : `https://${appUrl.replace(/\/$/, "")}`
  }

  const url = new URL(request.url)
  return `${url.protocol}//${url.host}`
}

function getCheckoutRedirectUrl(request: NextRequest): string {
  const explicit = process.env.SQUARE_CHECKOUT_REDIRECT_URL?.trim()
  if (explicit) return explicit
  return `${getRequestOrigin(request)}/paid`
}

function getMonthlyPlanId(offerCode: OfferCode): string | undefined {
  if (offerCode === "PROMO_CODE_REDACTED") {
    return (
      process.env.SQUARE_PLAN_ID_EARLY_BIRD?.trim() ||
      process.env.SQUARE_MONTHLY_PLAN_ID_EARLY_BIRD?.trim() ||
      undefined
    )
  }

  if (offerCode === "PROMO_CODE_REDACTED") {
    return (
      process.env.SQUARE_PLAN_ID_STANDARD?.trim() ||
      process.env.SQUARE_MONTHLY_PLAN_ID_STANDARD?.trim() ||
      undefined
    )
  }

  if (offerCode === "PROMO_CODE_REDACTED") {
    return (
      process.env.SQUARE_PLAN_ID_COST?.trim() ||
      process.env.SQUARE_MONTHLY_PLAN_ID_COST?.trim() ||
      undefined
    )
  }

  return undefined
}

function getUserPrimaryEmail(user: User): string | undefined {
  const userAsAny = user as unknown as {
    primaryEmailAddress?: { emailAddress?: string | null } | null
    emailAddresses?: Array<{ emailAddress?: string | null }> | null
  }

  return (
    userAsAny.primaryEmailAddress?.emailAddress ||
    userAsAny.emailAddresses?.[0]?.emailAddress ||
    undefined
  )
}

async function listUsersForLaunchStats(
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

export async function POST(request: NextRequest) {
  const { userId } = await auth()
  if (!userId) {
    return NextResponse.json({ ok: false, error: "Authentication required." }, { status: 401 })
  }

  const squareAccessToken = process.env.SQUARE_ACCESS_TOKEN?.trim()
  if (!squareAccessToken) {
    return NextResponse.json({ ok: false, error: "Square is not configured." }, { status: 500 })
  }

  const client = await clerkClient()
  const user = await client.users.getUser(userId)

  let payload: CheckoutPayload = {}
  try {
    payload = (await request.json()) as CheckoutPayload
  } catch {
    payload = {}
  }

  const offerType = parseOfferType(payload.offerType)
  const users = await listUsersForLaunchStats(client)
  const stats = collectLaunchStats(users)
  let offer = resolveCheckoutOffer(stats, offerType)

  const billing = getBillingMetadata(user)
  const override = billing.checkoutOfferOverride
  const overrideExpiresAt = billing.checkoutOfferOverrideExpiresAt || undefined
  const overrideExpiresAtMs = overrideExpiresAt ? Date.parse(overrideExpiresAt) : undefined
  const overrideValid =
    override === "PROMO_CODE_REDACTED" &&
    (!overrideExpiresAt ||
      (typeof overrideExpiresAtMs === "number" &&
        Number.isFinite(overrideExpiresAtMs) &&
        overrideExpiresAtMs > Date.now()))

  if (overrideValid && offerType === "monthly") {
    const costCents = getBillingCostPromoCents()
    if (!costCents) {
      return NextResponse.json(
        { ok: false, error: "Billing cost promo is not configured (PROMO_BILLING_COST_CENTS)." },
        { status: 500 },
      )
    }
    offer = {
      code: "PROMO_CODE_REDACTED",
      amountCents: costCents,
      currency: "USD",
      interval: "monthly",
      label: `$${(costCents / 100).toFixed(2)}/mo cost`,
    }
  }

  if (!offer) {
    return NextResponse.json(
      {
        ok: false,
        error: "That offer is sold out.",
      },
      { status: 409 },
    )
  }

  const environment = resolveSquareEnvironment(process.env.SQUARE_ENV)
  const locationId = process.env.SQUARE_LOCATION_ID?.trim()
  const monthlyPlanId = getMonthlyPlanId(offer.code)

  if (!locationId) {
    return NextResponse.json(
      {
        ok: false,
        error: "Missing SQUARE_LOCATION_ID for checkout.",
      },
      { status: 500 },
    )
  }

  if (offer.interval === "monthly" && !monthlyPlanId) {
    return NextResponse.json(
      {
        ok: false,
        error: "Missing Square subscription plan id for monthly checkout.",
      },
      { status: 500 },
    )
  }

  const now = new Date().toISOString()
  const metadataToken = encodeSquareMetadataToken({
    clerkUserId: userId,
    offerCode: offer.code,
    checkoutAt: now,
  })

  const idempotencyDate = now.slice(0, 10)
  const idempotencyKey = `txtclaw:${userId}:${offer.code}:${idempotencyDate}`

  try {
    const checkout = await createSquareCheckoutLink({
      environment,
      accessToken: squareAccessToken,
      locationId: locationId || "",
      idempotencyKey,
      redirectUrl: getCheckoutRedirectUrl(request),
      note: metadataToken,
      buyerEmail: getUserPrimaryEmail(user),
      amountCents: offer.amountCents,
      currency: offer.currency,
      quickPayName:
        offer.interval === "monthly"
          ? offer.code === "PROMO_CODE_REDACTED"
            ? "TXT CLAW Dev API Cost"
            : "TXT CLAW Dev API Pro"
          : "TXT CLAW BYOK Lifetime",
      subscriptionPlanId: offer.interval === "monthly" ? monthlyPlanId : undefined,
    })

    const publicMetadata = mergeBetaState(user, {
      betaState: "invited_to_pay",
      offerCode: offer.code,
    })
    const privateMetadata = getUserPrivateMetadata(user)
    const squareMetadata = mergeSquareMetadata(user, {
      pendingOfferCode: offer.code,
      pendingOrderId: checkout.orderId || undefined,
      pendingCheckoutId: checkout.id,
      pendingCheckoutUrl: checkout.url,
      lastOrderId: checkout.orderId || undefined,
    })
    const billingMetadata = mergeBillingMetadata(user, {
      offerCode: offer.code,
      paymentStatus: "checkout_created",
      purchaseType: offer.code === "PROMO_CODE_REDACTED" ? "lifetime" : "subscription",
      amountCents: offer.amountCents,
      currency: offer.currency,
      checkoutOfferType: offerType,
      checkoutLinkId: checkout.id,
      checkoutUrl: checkout.url,
      checkoutCreatedAt: now,
      paidAt: undefined,
      status: "invited_to_pay",
    })

    await client.users.updateUserMetadata(userId, {
      publicMetadata,
      privateMetadata: {
        ...privateMetadata,
        square: squareMetadata,
        billing: billingMetadata,
      },
    })

    return NextResponse.json(
      {
        ok: true,
        checkoutUrl: checkout.url,
        offer: {
          code: offer.code,
          amountCents: offer.amountCents,
          currency: offer.currency,
          interval: offer.interval,
          label: offer.label,
        },
        stats: {
          earlyBirdClaimed: stats.earlyBirdClaimed,
          earlyBirdCap: stats.earlyBirdCap,
          ltdClaimed: stats.ltdClaimed,
          ltdCap: stats.ltdCap,
        },
      },
      { status: 200 },
    )
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Unable to create checkout right now.",
      },
      { status: 500 },
    )
  }
}
