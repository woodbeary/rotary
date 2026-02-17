import {
  type OfferCode,
  getUserOfferCode,
  getUserPrivateMetadata,
  mergeBetaState,
  mergeBillingMetadata,
  mergeSquareMetadata,
} from "@/lib/billing"
import {
  type SquareWebhookEvent,
  decodeSquareMetadataToken,
  verifySquareWebhookSignature,
} from "@/lib/square"
import { type User, clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000

type SquarePaymentObject = {
  id?: unknown
  status?: unknown
  order_id?: unknown
  customer_id?: unknown
  subscription_id?: unknown
  note?: unknown
  amount_money?: {
    amount?: unknown
    currency?: unknown
  }
  updated_at?: unknown
  created_at?: unknown
}

type SquareSubscriptionObject = {
  id?: unknown
  status?: unknown
  customer_id?: unknown
  note?: unknown
  updated_at?: unknown
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : undefined
}

function asNumber(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value
  if (typeof value === "string") {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) return parsed
  }
  return undefined
}

function inferOfferFromAmount(amountCents: number | undefined): OfferCode | undefined {
  if (amountCents === 1600) return "PROMO_CODE_REDACTED"
  if (amountCents === 1900) return "PROMO_CODE_REDACTED"
  if (amountCents === 29900) return "PROMO_CODE_REDACTED"
  return undefined
}

function inferOfferCode(args: {
  tokenOfferCode?: string
  user?: User
  amountCents?: number
}): OfferCode | undefined {
  const tokenOffer = args.tokenOfferCode
  if (
    tokenOffer === "PROMO_CODE_REDACTED" ||
    tokenOffer === "PROMO_CODE_REDACTED" ||
    tokenOffer === "PROMO_CODE_REDACTED"
  ) {
    return tokenOffer
  }

  const userOffer = args.user ? getUserOfferCode(args.user) : undefined
  if (userOffer) return userOffer

  return inferOfferFromAmount(args.amountCents)
}

function getNotificationUrl(request: NextRequest): string {
  const explicit = process.env.SQUARE_WEBHOOK_NOTIFICATION_URL?.trim()
  if (explicit) return explicit

  const url = new URL(request.url)
  return `${url.protocol}//${url.host}${url.pathname}`
}

async function listUsers(client: Awaited<ReturnType<typeof clerkClient>>): Promise<User[]> {
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

function findUserByOrder(users: User[], orderId: string | undefined): User | undefined {
  if (!orderId) return undefined

  return users.find((user) => {
    const privateMetadata = getUserPrivateMetadata(user)
    const square = (privateMetadata.square as Record<string, unknown> | undefined) || {}
    const lastOrderId = asString(square.lastOrderId)
    const pendingOrderId = asString(square.pendingOrderId)
    return lastOrderId === orderId || pendingOrderId === orderId
  })
}

function findUserByCustomer(users: User[], customerId: string | undefined): User | undefined {
  if (!customerId) return undefined

  return users.find((user) => {
    const privateMetadata = getUserPrivateMetadata(user)
    const square = (privateMetadata.square as Record<string, unknown> | undefined) || {}
    return asString(square.customerId) === customerId
  })
}

function findUserBySubscription(
  users: User[],
  subscriptionId: string | undefined,
): User | undefined {
  if (!subscriptionId) return undefined

  return users.find((user) => {
    const privateMetadata = getUserPrivateMetadata(user)
    const square = (privateMetadata.square as Record<string, unknown> | undefined) || {}
    return asString(square.subscriptionId) === subscriptionId
  })
}

async function resolveTargetUser(args: {
  client: Awaited<ReturnType<typeof clerkClient>>
  users: User[]
  payment?: SquarePaymentObject
  subscription?: SquareSubscriptionObject
}): Promise<{ user: User; tokenOfferCode?: string } | null> {
  const noteCandidates = [asString(args.payment?.note), asString(args.subscription?.note)]

  for (const note of noteCandidates) {
    const token = decodeSquareMetadataToken(note)
    if (!token) continue

    try {
      const user = await args.client.users.getUser(token.clerkUserId)
      return { user, tokenOfferCode: token.offerCode }
    } catch {
      // Fall through to other strategies.
    }
  }

  const orderId = asString(args.payment?.order_id)
  const byOrder = findUserByOrder(args.users, orderId)
  if (byOrder) return { user: byOrder }

  const customerId = asString(args.payment?.customer_id) || asString(args.subscription?.customer_id)
  const byCustomer = findUserByCustomer(args.users, customerId)
  if (byCustomer) return { user: byCustomer }

  const subscriptionId = asString(args.payment?.subscription_id) || asString(args.subscription?.id)
  const bySubscription = findUserBySubscription(args.users, subscriptionId)
  if (bySubscription) return { user: bySubscription }

  return null
}

function isSuccessPayment(payment: SquarePaymentObject | undefined): boolean {
  const status = asString(payment?.status)?.toUpperCase()
  return status === "COMPLETED"
}

function isSuccessSubscription(subscription: SquareSubscriptionObject | undefined): boolean {
  const status = asString(subscription?.status)?.toUpperCase()
  return status === "ACTIVE"
}

async function syncDevApiPlanToWorker(args: {
  userId: string
  offerCode: OfferCode
  paidAt: string
}): Promise<{ ok: true } | { ok: false; error: string }> {
  const baseUrl = String(process.env.TXTCLAW_CONSOLE_BASE_URL || "").trim()
  const token = String(process.env.TXTCLAW_CONSOLE_SERVICE_TOKEN || "").trim()

  if (!baseUrl) return { ok: false, error: "Missing TXTCLAW_CONSOLE_BASE_URL." }
  if (!token) return { ok: false, error: "Missing TXTCLAW_CONSOLE_SERVICE_TOKEN." }

  try {
    const res = await fetch(`${baseUrl.replace(/\/+$/, "")}/console/v1/plan/sync`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: args.userId,
        offer_code: args.offerCode,
        paid_at: args.paidAt,
      }),
    })

    const text = await res.text().catch(() => "")
    if (!res.ok) {
      return { ok: false, error: `Worker plan sync failed (${res.status}): ${text}` }
    }

    const json = text ? (JSON.parse(text) as any) : null
    if (!json?.ok) {
      return { ok: false, error: `Worker plan sync rejected: ${text || "invalid JSON"}` }
    }

    return { ok: true }
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error.message : "Worker plan sync failed." }
  }
}

export async function POST(request: NextRequest) {
  const signatureKey = process.env.SQUARE_WEBHOOK_SIGNATURE_KEY?.trim()
  if (!signatureKey) {
    return NextResponse.json(
      { ok: false, error: "Missing SQUARE_WEBHOOK_SIGNATURE_KEY." },
      { status: 500 },
    )
  }

  const rawBody = await request.text()
  const signatureValid = await verifySquareWebhookSignature({
    signatureKey,
    expectedSignature: request.headers.get("x-square-hmacsha256-signature"),
    notificationUrl: getNotificationUrl(request),
    rawBody,
  })

  if (!signatureValid) {
    return NextResponse.json({ ok: false, error: "Invalid webhook signature." }, { status: 401 })
  }

  let event: SquareWebhookEvent
  try {
    event = JSON.parse(rawBody) as SquareWebhookEvent
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON payload." }, { status: 400 })
  }

  const eventId = asString(event.event_id)
  const eventType = asString(event.type)

  if (!eventId || !eventType) {
    return NextResponse.json({ ok: false, error: "Invalid event payload." }, { status: 400 })
  }

  const payment = (event.data?.object?.payment || undefined) as SquarePaymentObject | undefined
  const subscription = (event.data?.object?.subscription || undefined) as
    | SquareSubscriptionObject
    | undefined

  const successPayment = isSuccessPayment(payment)
  const successSubscription = isSuccessSubscription(subscription)

  if (!successPayment && !successSubscription) {
    return NextResponse.json(
      {
        ok: true,
        ignored: true,
        reason: "non_success_event",
        eventType,
      },
      { status: 200 },
    )
  }

  const client = await clerkClient()
  const users = await listUsers(client)
  const match = await resolveTargetUser({
    client,
    users,
    payment,
    subscription,
  })

  if (!match) {
    return NextResponse.json(
      {
        ok: true,
        ignored: true,
        reason: "unmatched_user",
        eventType,
      },
      { status: 200 },
    )
  }

  const user = match.user
  const userId = user.id

  const paymentId = asString(payment?.id)
  const orderId = asString(payment?.order_id)
  const customerId = asString(payment?.customer_id) || asString(subscription?.customer_id)
  const subscriptionId = asString(payment?.subscription_id) || asString(subscription?.id)

  const amountCents = asNumber(payment?.amount_money?.amount)
  const currency = asString(payment?.amount_money?.currency) || "USD"

  const paidAt =
    asString(payment?.updated_at) ||
    asString(payment?.created_at) ||
    asString(subscription?.updated_at) ||
    asString(event.created_at) ||
    new Date().toISOString()

  const offerCode = inferOfferCode({
    tokenOfferCode: match.tokenOfferCode,
    user,
    amountCents,
  })

  if (!offerCode) {
    return NextResponse.json(
      {
        ok: true,
        ignored: true,
        reason: "unable_to_resolve_offer",
        eventType,
      },
      { status: 200 },
    )
  }

  const publicMetadata = mergeBetaState(user, {
    betaState: "paid_waiting_apple_invite",
    offerCode,
  })

  const privateMetadata = getUserPrivateMetadata(user)
  const squareMetadata = mergeSquareMetadata(user, {
    customerId,
    subscriptionId,
    lastPaymentId: paymentId,
    lastOrderId: orderId,
    pendingOrderId: undefined,
    pendingCheckoutId: undefined,
    pendingCheckoutUrl: undefined,
    pendingOfferCode: undefined,
  })
  const billingMetadata = mergeBillingMetadata(user, {
    paidAt,
    offerCode,
    paymentStatus: successPayment ? "completed" : "subscription_active",
    purchaseType: offerCode === "PROMO_CODE_REDACTED" ? "lifetime" : "subscription",
    amountCents,
    currency,
    lastEventType: eventType,
    lastEventId: eventId,
    status: "paid_waiting_apple_invite",
  })

  await client.users.updateUserMetadata(userId, {
    publicMetadata,
    privateMetadata: {
      ...privateMetadata,
      square: squareMetadata,
      billing: billingMetadata,
    },
  })

  // Best-effort sync: update the Worker plan caps for this Clerk user.
  // Never fail the Square webhook because the Worker is unreachable.
  const workerSync = await syncDevApiPlanToWorker({ userId, offerCode, paidAt })

  return NextResponse.json(
    {
      ok: true,
      userId,
      eventType,
      offerCode,
      betaState: "paid_waiting_apple_invite",
      workerPlanSyncOk: workerSync.ok,
      workerPlanSyncError: workerSync.ok ? undefined : workerSync.error,
    },
    { status: 200 },
  )
}
