import type { User } from "@clerk/nextjs/server"

type MetadataRecord = Record<string, unknown>

export type BillingCostPromoMetadata = {
  redeemedCodeIds: string[]
  campaignClaims: Record<string, string>
}

function asRecord(value: unknown): MetadataRecord {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {}
  return value as MetadataRecord
}

function asString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined
  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : undefined
}

function normalizeCodeId(value: unknown): string | undefined {
  const raw = asString(value)
  if (!raw) return undefined
  const normalized = raw.toUpperCase()
  return /^[A-F0-9]+$/.test(normalized) ? normalized : undefined
}

function normalizeCampaignId(value: unknown): string | undefined {
  return asString(value)
}

function dedupe(values: string[]): string[] {
  return Array.from(new Set(values))
}

export function getBillingCostPromoMetadata(user: User): BillingCostPromoMetadata {
  const privateMetadata = asRecord((user as any).privateMetadata)
  const promos = asRecord(privateMetadata.billingCostPromos)

  const redeemedRaw = Array.isArray(promos.redeemedCodeIds) ? promos.redeemedCodeIds : []
  const redeemedCodeIds = dedupe(
    redeemedRaw
      .map((value) => normalizeCodeId(value))
      .filter((value): value is string => typeof value === "string"),
  )

  const claimsRecord = asRecord(promos.campaignClaims)
  const campaignClaims: Record<string, string> = {}
  for (const [campaignIdRaw, claimedCodeIdRaw] of Object.entries(claimsRecord)) {
    const campaignId = normalizeCampaignId(campaignIdRaw)
    const claimedCodeId = normalizeCodeId(claimedCodeIdRaw)
    if (!campaignId || !claimedCodeId) continue
    campaignClaims[campaignId] = claimedCodeId
  }

  return { redeemedCodeIds, campaignClaims }
}

export function hasBillingCostCodeBeenRedeemed(
  promos: BillingCostPromoMetadata,
  codeIdRaw: string,
): boolean {
  const codeId = normalizeCodeId(codeIdRaw)
  if (!codeId) return false
  if (promos.redeemedCodeIds.includes(codeId)) return true
  return Object.values(promos.campaignClaims).includes(codeId)
}

export function getBillingCostCampaignClaimCodeId(
  promos: BillingCostPromoMetadata,
  campaignIdRaw: string,
): string | undefined {
  const campaignId = normalizeCampaignId(campaignIdRaw)
  if (!campaignId) return undefined
  return promos.campaignClaims[campaignId]
}

export function applyBillingCostCodeRedemption(args: {
  promos: BillingCostPromoMetadata
  campaignId: string
  codeId: string
}): { promos: BillingCostPromoMetadata; idempotent: boolean } {
  const campaignId = normalizeCampaignId(args.campaignId)
  const codeId = normalizeCodeId(args.codeId)
  if (!campaignId) throw new Error("campaignId is required.")
  if (!codeId) throw new Error("codeId must be uppercase hex.")

  const existingClaim = args.promos.campaignClaims[campaignId]
  if (existingClaim && existingClaim !== codeId) {
    throw new Error("Campaign already claimed by this account.")
  }

  if (hasBillingCostCodeBeenRedeemed(args.promos, codeId)) {
    return { promos: args.promos, idempotent: true }
  }

  return {
    promos: {
      redeemedCodeIds: dedupe(args.promos.redeemedCodeIds.concat(codeId)),
      campaignClaims: {
        ...args.promos.campaignClaims,
        [campaignId]: codeId,
      },
    },
    idempotent: false,
  }
}
