import type { User } from "@clerk/nextjs/server"

type MetadataRecord = Record<string, unknown>

export type PromotionGrant = {
  campaignId: string
  codeId: string
  amountCents: number
  grantedAt: string
}

export type PromotionsMetadata = {
  grants: PromotionGrant[]
  redeemedCodeIds: string[]
  totalGrantedCents: number
  balanceCents: number
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

function asNonNegativeInteger(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
    return Math.floor(value)
  }
  if (typeof value === "string") {
    const parsed = Number(value)
    if (Number.isFinite(parsed) && parsed >= 0) {
      return Math.floor(parsed)
    }
  }
  return undefined
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

function parsePromotionGrant(value: unknown): PromotionGrant | null {
  const record = asRecord(value)
  const campaignId = normalizeCampaignId(record.campaignId)
  const codeId = normalizeCodeId(record.codeId)
  const amountCents = asNonNegativeInteger(record.amountCents)
  const grantedAt = asString(record.grantedAt)

  if (!campaignId || !codeId || !grantedAt) return null
  if (!amountCents || amountCents <= 0) return null

  return {
    campaignId,
    codeId,
    amountCents,
    grantedAt,
  }
}

function dedupeCodeIds(values: string[]): string[] {
  return Array.from(new Set(values))
}

function clonePromotionsMetadata(promotions: PromotionsMetadata): PromotionsMetadata {
  return {
    grants: promotions.grants.map((grant) => ({ ...grant })),
    redeemedCodeIds: [...promotions.redeemedCodeIds],
    totalGrantedCents: promotions.totalGrantedCents,
    balanceCents: promotions.balanceCents,
    campaignClaims: { ...promotions.campaignClaims },
  }
}

export function getPromotionsMetadata(user: User): PromotionsMetadata {
  const privateMetadata = asRecord(user.privateMetadata)
  const promotionsRecord = asRecord(privateMetadata.promotions)

  const grantsRaw = Array.isArray(promotionsRecord.grants) ? promotionsRecord.grants : []
  const grants = grantsRaw
    .map((item) => parsePromotionGrant(item))
    .filter((item): item is PromotionGrant => item !== null)

  const campaignClaimsRecord = asRecord(promotionsRecord.campaignClaims)
  const campaignClaims: Record<string, string> = {}
  for (const [campaignIdRaw, claimedCodeIdRaw] of Object.entries(campaignClaimsRecord)) {
    const campaignId = normalizeCampaignId(campaignIdRaw)
    const claimedCodeId = normalizeCodeId(claimedCodeIdRaw)
    if (!campaignId || !claimedCodeId) continue
    campaignClaims[campaignId] = claimedCodeId
  }

  for (const grant of grants) {
    if (!campaignClaims[grant.campaignId]) {
      campaignClaims[grant.campaignId] = grant.codeId
    }
  }

  const redeemedCodeIdsRaw = Array.isArray(promotionsRecord.redeemedCodeIds)
    ? promotionsRecord.redeemedCodeIds
    : []
  const redeemedCodeIds = dedupeCodeIds(
    redeemedCodeIdsRaw
      .map((value) => normalizeCodeId(value))
      .filter((value): value is string => typeof value === "string")
      .concat(grants.map((grant) => grant.codeId))
      .concat(Object.values(campaignClaims)),
  )

  const derivedTotalGranted = grants.reduce((sum, grant) => sum + grant.amountCents, 0)
  const totalGrantedCents =
    asNonNegativeInteger(promotionsRecord.totalGrantedCents) ?? derivedTotalGranted
  const balanceCents = asNonNegativeInteger(promotionsRecord.balanceCents) ?? totalGrantedCents

  return {
    grants,
    redeemedCodeIds,
    totalGrantedCents,
    balanceCents,
    campaignClaims,
  }
}

export function hasCodeBeenRedeemed(promotions: PromotionsMetadata, codeIdRaw: string): boolean {
  const codeId = normalizeCodeId(codeIdRaw)
  if (!codeId) return false

  if (promotions.redeemedCodeIds.includes(codeId)) return true
  if (promotions.grants.some((grant) => grant.codeId === codeId)) return true
  return Object.values(promotions.campaignClaims).includes(codeId)
}

export function getCampaignClaimCodeId(
  promotions: PromotionsMetadata,
  campaignIdRaw: string,
): string | undefined {
  const campaignId = normalizeCampaignId(campaignIdRaw)
  if (!campaignId) return undefined
  return promotions.campaignClaims[campaignId]
}

export function applyPromotionGrant(args: {
  promotions: PromotionsMetadata
  campaignId: string
  codeId: string
  amountCents: number
  grantedAt?: string
}): {
  promotions: PromotionsMetadata
  idempotent: boolean
} {
  const campaignId = normalizeCampaignId(args.campaignId)
  const codeId = normalizeCodeId(args.codeId)
  const amountCents = asNonNegativeInteger(args.amountCents)
  const grantedAt = asString(args.grantedAt) || new Date().toISOString()

  if (!campaignId) {
    throw new Error("campaignId is required.")
  }
  if (!codeId) {
    throw new Error("codeId must be uppercase hex.")
  }
  if (!amountCents || amountCents <= 0) {
    throw new Error("amountCents must be a positive integer.")
  }

  const current = clonePromotionsMetadata(args.promotions)
  const existingClaim = current.campaignClaims[campaignId]
  if (existingClaim && existingClaim !== codeId) {
    throw new Error("Campaign already claimed by this user.")
  }

  if (hasCodeBeenRedeemed(current, codeId)) {
    return {
      promotions: current,
      idempotent: true,
    }
  }

  const nextGrants = current.grants.concat({
    campaignId,
    codeId,
    amountCents,
    grantedAt,
  })
  const nextRedeemedCodeIds = dedupeCodeIds(current.redeemedCodeIds.concat(codeId))
  const nextTotalGrantedCents = current.totalGrantedCents + amountCents
  const nextBalanceCents = current.balanceCents + amountCents

  return {
    promotions: {
      grants: nextGrants,
      redeemedCodeIds: nextRedeemedCodeIds,
      totalGrantedCents: nextTotalGrantedCents,
      balanceCents: nextBalanceCents,
      campaignClaims: {
        ...current.campaignClaims,
        [campaignId]: codeId,
      },
    },
    idempotent: false,
  }
}
