import { createHmac, timingSafeEqual } from "node:crypto"

export type SquareEnvironment = "sandbox" | "production"

export type SquareCheckoutLink = {
  id: string
  url: string
  orderId: string | null
}

export type SquareWebhookEvent = {
  event_id?: string
  type?: string
  created_at?: string
  data?: {
    object?: {
      payment?: Record<string, unknown>
      order?: Record<string, unknown>
      subscription?: Record<string, unknown>
    }
  }
}

export type SquareMetadataToken = {
  clerkUserId: string
  offerCode: string
  checkoutAt: string
}

const SQUARE_METADATA_PREFIX = "txtclaw_meta:"

function getSquareBaseUrl(environment: SquareEnvironment): string {
  return environment === "production"
    ? "https://connect.squareup.com"
    : "https://connect.squareupsandbox.com"
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : undefined
}

function safeEquals(a: string, b: string): boolean {
  const aBuffer = Buffer.from(a)
  const bBuffer = Buffer.from(b)
  if (aBuffer.length !== bBuffer.length) return false
  return timingSafeEqual(aBuffer, bBuffer)
}

export function resolveSquareEnvironment(value: string | undefined): SquareEnvironment {
  return value === "production" ? "production" : "sandbox"
}

export function encodeSquareMetadataToken(payload: SquareMetadataToken): string {
  const raw = JSON.stringify(payload)
  const encoded = Buffer.from(raw, "utf8").toString("base64url")
  return `${SQUARE_METADATA_PREFIX}${encoded}`
}

export function decodeSquareMetadataToken(note: unknown): SquareMetadataToken | null {
  const raw = asString(note)
  if (!raw) return null
  if (!raw.startsWith(SQUARE_METADATA_PREFIX)) return null

  const encoded = raw.slice(SQUARE_METADATA_PREFIX.length)
  if (!encoded) return null

  try {
    const decoded = Buffer.from(encoded, "base64url").toString("utf8")
    const parsed = JSON.parse(decoded) as Partial<SquareMetadataToken>
    if (
      typeof parsed?.clerkUserId !== "string" ||
      typeof parsed?.offerCode !== "string" ||
      typeof parsed?.checkoutAt !== "string"
    ) {
      return null
    }

    return {
      clerkUserId: parsed.clerkUserId,
      offerCode: parsed.offerCode,
      checkoutAt: parsed.checkoutAt,
    }
  } catch {
    return null
  }
}

async function squareFetch(args: {
  environment: SquareEnvironment
  accessToken: string
  path: string
  init?: RequestInit
}): Promise<Response> {
  const url = `${getSquareBaseUrl(args.environment)}${args.path}`

  return fetch(url, {
    ...args.init,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.accessToken}`,
      ...(args.init?.headers || {}),
    },
  })
}

export async function createSquareCheckoutLink(args: {
  environment: SquareEnvironment
  accessToken: string
  locationId: string
  idempotencyKey: string
  redirectUrl?: string
  note: string
  buyerEmail?: string
  amountCents: number
  currency: string
  quickPayName: string
  subscriptionPlanId?: string
}): Promise<SquareCheckoutLink> {
  const checkoutOptions: Record<string, unknown> = {}
  if (args.redirectUrl) {
    checkoutOptions.redirect_url = args.redirectUrl
  }

  const hasSubscriptionPlan = Boolean(args.subscriptionPlanId)
  if (hasSubscriptionPlan && args.subscriptionPlanId) {
    checkoutOptions.subscription_plan_id = args.subscriptionPlanId
  }

  const requestBody: Record<string, unknown> = {
    idempotency_key: args.idempotencyKey,
    payment_note: args.note,
    checkout_options: Object.keys(checkoutOptions).length > 0 ? checkoutOptions : undefined,
    pre_populated_data: args.buyerEmail
      ? {
          buyer_email: args.buyerEmail,
        }
      : undefined,
  }

  // Square still expects quick_pay/order payload even when subscription_plan_id is present.
  requestBody.quick_pay = {
    name: args.quickPayName,
    location_id: args.locationId,
    price_money: {
      amount: args.amountCents,
      currency: args.currency,
    },
  }

  const response = await squareFetch({
    environment: args.environment,
    accessToken: args.accessToken,
    path: "/v2/online-checkout/payment-links",
    init: {
      method: "POST",
      body: JSON.stringify(requestBody),
    },
  })

  const text = await response.text()
  if (!response.ok) {
    throw new Error(`Square checkout link failed (${response.status}): ${text}`)
  }

  const json = JSON.parse(text) as {
    payment_link?: {
      id?: string
      url?: string
      order_id?: string | null
    }
  }

  const linkId = asString(json.payment_link?.id)
  const linkUrl = asString(json.payment_link?.url)

  if (!linkId || !linkUrl) {
    throw new Error("Square checkout link response missing id/url")
  }

  return {
    id: linkId,
    url: linkUrl,
    orderId: asString(json.payment_link?.order_id) || null,
  }
}

export async function verifySquareWebhookSignature(args: {
  signatureKey: string
  expectedSignature: string | null
  notificationUrl: string
  rawBody: string
}): Promise<boolean> {
  const expectedSignature = asString(args.expectedSignature)
  if (!expectedSignature) return false

  const payload = `${args.notificationUrl}${args.rawBody}`
  const actualSignature = createHmac("sha256", args.signatureKey)
    .update(payload, "utf8")
    .digest("base64")

  return safeEquals(actualSignature, expectedSignature)
}
