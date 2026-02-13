import {
  PROMO_CODE_DEFAULT_CAMPAIGN_ID,
  PROMO_CODE_DEFAULT_GRANT_CENTS,
  parsePromoGrantCents,
  parsePromoRedeemEnabled,
} from "@/lib/promo-codes"

function parseBoolean(raw: string | undefined, fallback: boolean): boolean {
  if (!raw?.trim()) return fallback
  const normalized = raw.trim().toLowerCase()
  if (["1", "true", "yes", "on"].includes(normalized)) return true
  if (["0", "false", "no", "off"].includes(normalized)) return false
  return fallback
}

function parseAdminUserIds(raw: string | undefined): string[] {
  if (!raw?.trim()) return []

  return raw
    .split(",")
    .map((part) => part.trim())
    .filter((part) => part.length > 0)
}

export function getPromoCampaignId(): string {
  return process.env.PROMO_CAMPAIGN_ID?.trim() || PROMO_CODE_DEFAULT_CAMPAIGN_ID
}

export function getPromoGrantCents(): number {
  return parsePromoGrantCents(
    process.env.PROMO_GRANT_CENTS,
    PROMO_CODE_DEFAULT_GRANT_CENTS
  )
}

export function isPromoRedeemEnabled(): boolean {
  return parsePromoRedeemEnabled(process.env.PROMO_REDEEM_ENABLED)
}

export function isPromoGenerateEnabled(): boolean {
  return parseBoolean(process.env.PROMO_GENERATE_ENABLED, false)
}

export function canUserGeneratePromoCodes(userId: string | null | undefined): boolean {
  if (!userId) return false
  if (!isPromoGenerateEnabled()) return false

  const adminUserIds = parseAdminUserIds(process.env.PROMO_ADMIN_USER_IDS)
  if (adminUserIds.length === 0) return true

  return adminUserIds.includes(userId)
}
