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
  return parsePromoGrantCents(process.env.PROMO_GRANT_CENTS, PROMO_CODE_DEFAULT_GRANT_CENTS)
}

export function isPromoRedeemEnabled(): boolean {
  return parsePromoRedeemEnabled(process.env.PROMO_REDEEM_ENABLED)
}

export function isPromoGenerateEnabled(): boolean {
  return parseBoolean(process.env.PROMO_GENERATE_ENABLED, false)
}

export function isDevApiPromoEnabled(): boolean {
  return parseBoolean(process.env.PROMO_DEV_API_ENABLED, false)
}

export function isBillingCostPromoEnabled(): boolean {
  return parseBoolean(process.env.PROMO_BILLING_COST_ENABLED, false)
}

export function getBillingCostPromoCampaignId(): string {
  return process.env.PROMO_BILLING_COST_CAMPAIGN_ID?.trim() || "x_billing_cost_2026_02"
}

export function getBillingCostPromoCents(): number {
  const raw = process.env.PROMO_BILLING_COST_CENTS?.trim()
  if (!raw) return 0
  const parsed = Number(raw)
  if (!Number.isFinite(parsed) || parsed <= 0) return 0
  return Math.floor(parsed)
}

export function getDevApiPromoCampaignId(): string {
  return process.env.PROMO_DEV_API_CAMPAIGN_ID?.trim() || "x_dev_api_tester_2026_02"
}

export function getDevApiPromoSignatureCents(): number {
  // Signature cents are only used to validate codes. This value is not shown to users.
  const raw = process.env.PROMO_DEV_API_SIGNATURE_CENTS?.trim()
  if (!raw) return 1
  const parsed = Number(raw)
  if (!Number.isFinite(parsed) || parsed <= 0) return 1
  return Math.floor(parsed)
}

export function getDevApiPromoPlan(): "free" | "pro" | "max" | "byok" {
  const raw = String(process.env.PROMO_DEV_API_PLAN || "")
    .trim()
    .toLowerCase()
  if (raw === "pro" || raw === "max" || raw === "byok") return raw
  return "free"
}

export function canUserGeneratePromoCodes(userId: string | null | undefined): boolean {
  if (!userId) return false
  if (!isPromoGenerateEnabled()) return false

  const adminUserIds = parseAdminUserIds(process.env.PROMO_ADMIN_USER_IDS)
  if (adminUserIds.length === 0) return false

  return adminUserIds.includes(userId)
}
