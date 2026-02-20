import type { User } from "@clerk/nextjs/server"

export const EARLY_BIRD_CAP = 100
export const LTD_CAP = 10

export const EARLY_BIRD_PRICE_CENTS = 1600
export const STANDARD_PRICE_CENTS = 1900
export const LTD_PRICE_CENTS = 29900
export const INVITE_TO_PAY_TTL_HOURS = 72

export type BetaState =
  | "waitlist_pending"
  | "invited_to_pay"
  | "paid_waiting_apple_invite"
  | "apple_invited"

export type OfferCode =
  | "PROMO_CODE_REDACTED"
  | "PROMO_CODE_REDACTED"
  | "PROMO_CODE_REDACTED"
  | "PROMO_CODE_REDACTED"

export type OfferType = "monthly" | "ltd"

export type LaunchOffer = {
  code: OfferCode
  amountCents: number
  currency: "USD"
  interval: "monthly" | "one_time"
  label: string
}

export type RecentPaidEntry = {
  initial: string
  timestamp: string
}

export type LaunchStats = {
  earlyBirdClaimed: number
  earlyBirdCap: number
  ltdClaimed: number
  ltdCap: number
  recentPaid: RecentPaidEntry[]
}

type MetadataRecord = Record<string, unknown>

type BillingMetadata = {
  paidAt?: string
  offerCode?: OfferCode
  paymentStatus?: string
  purchaseType?: "subscription" | "lifetime"
  invitedToPayAt?: string
  inviteExpiresAt?: string
  checkoutOfferOverride?: OfferCode | null
  checkoutOfferOverrideCodeId?: string | null
  checkoutOfferOverrideSetAt?: string | null
  checkoutOfferOverrideExpiresAt?: string | null
}

type SquareMetadata = {
  customerId?: string
  subscriptionId?: string
  lastPaymentId?: string
  lastOrderId?: string
  pendingOrderId?: string
  pendingCheckoutId?: string
  pendingCheckoutUrl?: string
  pendingOfferCode?: OfferCode
}

function asRecord(value: unknown): MetadataRecord {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {}
  }
  return value as MetadataRecord
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : undefined
}

function asOfferCode(value: unknown): OfferCode | undefined {
  const raw = asString(value)
  if (
    raw === "PROMO_CODE_REDACTED" ||
    raw === "PROMO_CODE_REDACTED" ||
    raw === "PROMO_CODE_REDACTED" ||
    raw === "PROMO_CODE_REDACTED"
  ) {
    return raw
  }
  return undefined
}

export function asBetaState(value: unknown): BetaState | undefined {
  const raw = asString(value)
  if (
    raw === "waitlist_pending" ||
    raw === "invited_to_pay" ||
    raw === "paid_waiting_apple_invite" ||
    raw === "apple_invited"
  ) {
    return raw
  }
  return undefined
}

export function parseOfferType(value: unknown): OfferType {
  return value === "ltd" ? "ltd" : "monthly"
}

export function getUserPublicMetadata(user: User): MetadataRecord {
  return asRecord(user.publicMetadata)
}

export function getUserPrivateMetadata(user: User): MetadataRecord {
  return asRecord(user.privateMetadata)
}

export function getUserBetaState(user: User): BetaState | undefined {
  const publicMetadata = getUserPublicMetadata(user)
  return asBetaState(publicMetadata.betaState)
}

export function getUserOfferCode(user: User): OfferCode | undefined {
  const publicMetadata = getUserPublicMetadata(user)
  const publicOffer = asOfferCode(publicMetadata.offerCode)
  if (publicOffer) return publicOffer

  const billing = getBillingMetadata(user)
  return billing.offerCode
}

export function getBillingMetadata(user: User): BillingMetadata {
  const privateMetadata = getUserPrivateMetadata(user)
  const billing = asRecord(privateMetadata.billing)
  const paidAt = asString(billing.paidAt)
  const offerCode = asOfferCode(billing.offerCode)
  const paymentStatus = asString(billing.paymentStatus)
  const invitedToPayAt = asString(billing.invitedToPayAt)
  const inviteExpiresAt = asString(billing.inviteExpiresAt)
  const purchaseTypeRaw = asString(billing.purchaseType)
  const purchaseType =
    purchaseTypeRaw === "subscription" || purchaseTypeRaw === "lifetime"
      ? purchaseTypeRaw
      : undefined
  const checkoutOfferOverride =
    billing.checkoutOfferOverride === null ? null : asOfferCode(billing.checkoutOfferOverride)
  const checkoutOfferOverrideCodeId =
    billing.checkoutOfferOverrideCodeId === null
      ? null
      : asString(billing.checkoutOfferOverrideCodeId)
  const checkoutOfferOverrideSetAt =
    billing.checkoutOfferOverrideSetAt === null
      ? null
      : asString(billing.checkoutOfferOverrideSetAt)
  const checkoutOfferOverrideExpiresAt =
    billing.checkoutOfferOverrideExpiresAt === null
      ? null
      : asString(billing.checkoutOfferOverrideExpiresAt)

  return {
    paidAt,
    offerCode,
    paymentStatus,
    purchaseType,
    invitedToPayAt,
    inviteExpiresAt,
    checkoutOfferOverride,
    checkoutOfferOverrideCodeId,
    checkoutOfferOverrideSetAt,
    checkoutOfferOverrideExpiresAt,
  }
}

export function getSquareMetadata(user: User): SquareMetadata {
  const privateMetadata = getUserPrivateMetadata(user)
  const square = asRecord(privateMetadata.square)

  return {
    customerId: asString(square.customerId),
    subscriptionId: asString(square.subscriptionId),
    lastPaymentId: asString(square.lastPaymentId),
    lastOrderId: asString(square.lastOrderId),
    pendingOrderId: asString(square.pendingOrderId),
    pendingCheckoutId: asString(square.pendingCheckoutId),
    pendingCheckoutUrl: asString(square.pendingCheckoutUrl),
    pendingOfferCode: asOfferCode(square.pendingOfferCode),
  }
}

export function hasSuccessfulPayment(user: User): boolean {
  const billing = getBillingMetadata(user)
  if (!billing.paidAt) return false
  return Boolean(getUserOfferCode(user))
}

function userPublicInitial(user: User): string {
  const userAsAny = user as unknown as {
    firstName?: string | null
    username?: string | null
    primaryEmailAddress?: { emailAddress?: string | null } | null
    emailAddresses?: Array<{ emailAddress?: string | null }> | null
  }

  const seed =
    userAsAny.firstName ||
    userAsAny.username ||
    userAsAny.primaryEmailAddress?.emailAddress ||
    userAsAny.emailAddresses?.[0]?.emailAddress ||
    "U"

  const firstChar = seed.trim().charAt(0)
  return firstChar ? firstChar.toUpperCase() : "U"
}

export function collectLaunchStats(users: User[]): LaunchStats {
  const recentPaid: RecentPaidEntry[] = []
  let earlyBirdClaimed = 0
  let ltdClaimed = 0

  for (const user of users) {
    if (!hasSuccessfulPayment(user)) continue

    const billing = getBillingMetadata(user)
    const paidAt = billing.paidAt
    if (!paidAt) continue

    const offerCode = getUserOfferCode(user)
    if (!offerCode) continue

    if (offerCode === "PROMO_CODE_REDACTED") {
      earlyBirdClaimed += 1
    }
    if (offerCode === "PROMO_CODE_REDACTED") {
      ltdClaimed += 1
    }

    recentPaid.push({
      initial: userPublicInitial(user),
      timestamp: paidAt,
    })
  }

  recentPaid.sort((a, b) => {
    const aMs = Date.parse(a.timestamp)
    const bMs = Date.parse(b.timestamp)
    if (!Number.isFinite(aMs) && !Number.isFinite(bMs)) return 0
    if (!Number.isFinite(aMs)) return 1
    if (!Number.isFinite(bMs)) return -1
    return bMs - aMs
  })

  return {
    earlyBirdClaimed,
    earlyBirdCap: EARLY_BIRD_CAP,
    ltdClaimed,
    ltdCap: LTD_CAP,
    recentPaid: recentPaid.slice(0, 20),
  }
}

export function resolveMonthlyOffer(stats: LaunchStats): LaunchOffer {
  if (stats.earlyBirdClaimed < EARLY_BIRD_CAP) {
    return {
      code: "PROMO_CODE_REDACTED",
      amountCents: EARLY_BIRD_PRICE_CENTS,
      currency: "USD",
      interval: "monthly",
      label: "$16/mo early bird",
    }
  }

  return {
    code: "PROMO_CODE_REDACTED",
    amountCents: STANDARD_PRICE_CENTS,
    currency: "USD",
    interval: "monthly",
    label: "$19/mo standard",
  }
}

export function resolveCheckoutOffer(stats: LaunchStats, offerType: OfferType): LaunchOffer | null {
  if (offerType === "ltd") {
    if (stats.ltdClaimed >= LTD_CAP) return null

    return {
      code: "PROMO_CODE_REDACTED",
      amountCents: LTD_PRICE_CENTS,
      currency: "USD",
      interval: "one_time",
      label: "$299 BYOK lifetime",
    }
  }

  return resolveMonthlyOffer(stats)
}

export function mergeBetaState(
  user: User,
  patch: {
    betaState?: BetaState
    offerCode?: OfferCode
  },
): MetadataRecord {
  const current = getUserPublicMetadata(user)

  return {
    ...current,
    ...(patch.betaState ? { betaState: patch.betaState } : {}),
    ...(patch.offerCode ? { offerCode: patch.offerCode } : {}),
  }
}

export function mergeSquareMetadata(user: User, patch: Partial<SquareMetadata>): MetadataRecord {
  const privateMetadata = getUserPrivateMetadata(user)
  const currentSquare = asRecord(privateMetadata.square)

  return {
    ...currentSquare,
    ...patch,
  }
}

export function mergeBillingMetadata(
  user: User,
  patch: Partial<BillingMetadata> & {
    status?: string
    amountCents?: number
    currency?: string
    checkoutCreatedAt?: string
    checkoutOfferType?: OfferType
    checkoutLinkId?: string
    checkoutUrl?: string
    lastEventType?: string
    lastEventId?: string
  },
): MetadataRecord {
  const privateMetadata = getUserPrivateMetadata(user)
  const currentBilling = asRecord(privateMetadata.billing)

  return {
    ...currentBilling,
    ...patch,
  }
}

export function toIsoFromEpochMs(value: number | undefined): string | undefined {
  if (!Number.isFinite(value)) return undefined
  return new Date(value as number).toISOString()
}

export function getInviteExpiryIso(invitedAtIso: string): string {
  const invitedAtMs = Date.parse(invitedAtIso)
  const ttlMs = INVITE_TO_PAY_TTL_HOURS * 60 * 60 * 1000
  return new Date(invitedAtMs + ttlMs).toISOString()
}

export function isInviteWindowOpen(invitedAtIso: string, now = new Date()): boolean {
  const invitedAtMs = Date.parse(invitedAtIso)
  if (!Number.isFinite(invitedAtMs)) return false
  const ttlMs = INVITE_TO_PAY_TTL_HOURS * 60 * 60 * 1000
  return now.getTime() - invitedAtMs <= ttlMs
}
