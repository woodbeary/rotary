import { createHmac, randomBytes, timingSafeEqual } from "node:crypto"

export const PROMO_CODE_PREFIX = "TXT100"
export const PROMO_CODE_DEFAULT_CAMPAIGN_ID = "x_launch_2026_02"
export const PROMO_CODE_DEFAULT_GRANT_CENTS = 10000

const CODE_ID_HEX_LENGTH = 12
const SIGNATURE_HEX_LENGTH = 8
const CODE_PATTERN = new RegExp(
  `^${PROMO_CODE_PREFIX}-([A-F0-9]{${CODE_ID_HEX_LENGTH}})-([A-F0-9]{${SIGNATURE_HEX_LENGTH}})$`
)

type VerifyPromoCodeErrorReason = "invalid_format" | "signature_mismatch"

export type VerifyPromoCodeResult =
  | {
      ok: true
      codeId: string
      normalizedCode: string
    }
  | {
      ok: false
      reason: VerifyPromoCodeErrorReason
    }

type ParsedPromoCode = {
  codeId: string
  signature: string
  normalized: string
}

function asTrimmedString(value: unknown): string {
  if (typeof value !== "string") return ""
  return value.trim()
}

function normalizeCode(rawCode: unknown): string {
  return asTrimmedString(rawCode).toUpperCase()
}

function normalizeCodeId(rawCodeId: string): string {
  return rawCodeId.trim().toUpperCase()
}

function normalizeSignature(rawSignature: string): string {
  return rawSignature.trim().toUpperCase()
}

function asPositiveInteger(value: number): number {
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error("amountCents must be a positive integer.")
  }
  return Math.floor(value)
}

function safeEquals(a: string, b: string): boolean {
  const aBuffer = Buffer.from(a, "utf8")
  const bBuffer = Buffer.from(b, "utf8")
  if (aBuffer.length !== bBuffer.length) return false
  return timingSafeEqual(aBuffer, bBuffer)
}

function getPromoSigningMessage(args: {
  campaignId: string
  amountCents: number
  codeId: string
}): string {
  return `v1:${args.campaignId}:${args.amountCents}:${args.codeId}`
}

function parsePromoCode(rawCode: unknown): ParsedPromoCode | null {
  const normalized = normalizeCode(rawCode)
  if (!normalized) return null

  const match = normalized.match(CODE_PATTERN)
  if (!match) return null

  const [, codeId, signature] = match
  return {
    codeId,
    signature,
    normalized,
  }
}

export function computePromoCodeSignature(args: {
  campaignId: string
  amountCents: number
  codeId: string
  secret: string
}): string {
  const codeId = normalizeCodeId(args.codeId)
  const amountCents = asPositiveInteger(args.amountCents)
  const message = getPromoSigningMessage({
    campaignId: args.campaignId,
    amountCents,
    codeId,
  })

  return createHmac("sha256", args.secret)
    .update(message, "utf8")
    .digest("hex")
    .slice(0, SIGNATURE_HEX_LENGTH)
    .toUpperCase()
}

export function formatPromoCode(args: { codeId: string; signature: string }): string {
  const codeId = normalizeCodeId(args.codeId)
  const signature = normalizeSignature(args.signature)
  return `${PROMO_CODE_PREFIX}-${codeId}-${signature}`
}

export function generatePromoCodeId(): string {
  return randomBytes(CODE_ID_HEX_LENGTH / 2).toString("hex").toUpperCase()
}

export function createPromoCode(args: {
  campaignId: string
  amountCents: number
  secret: string
  codeId?: string
}): {
  code: string
  codeId: string
  signature: string
} {
  const codeId = args.codeId ? normalizeCodeId(args.codeId) : generatePromoCodeId()
  if (!/^[A-F0-9]+$/.test(codeId) || codeId.length !== CODE_ID_HEX_LENGTH) {
    throw new Error(`codeId must be ${CODE_ID_HEX_LENGTH} uppercase hex characters.`)
  }

  const signature = computePromoCodeSignature({
    campaignId: args.campaignId,
    amountCents: args.amountCents,
    codeId,
    secret: args.secret,
  })

  return {
    code: formatPromoCode({ codeId, signature }),
    codeId,
    signature,
  }
}

export function verifyPromoCode(args: {
  code: unknown
  campaignId: string
  amountCents: number
  secret: string
}): VerifyPromoCodeResult {
  const parsed = parsePromoCode(args.code)
  if (!parsed) {
    return { ok: false, reason: "invalid_format" }
  }

  const expectedSignature = computePromoCodeSignature({
    campaignId: args.campaignId,
    amountCents: args.amountCents,
    codeId: parsed.codeId,
    secret: args.secret,
  })

  if (!safeEquals(parsed.signature, expectedSignature)) {
    return { ok: false, reason: "signature_mismatch" }
  }

  return {
    ok: true,
    codeId: parsed.codeId,
    normalizedCode: parsed.normalized,
  }
}

export function parsePromoGrantCents(
  raw: string | undefined,
  fallback = PROMO_CODE_DEFAULT_GRANT_CENTS
): number {
  if (!raw?.trim()) return fallback
  const value = Number(raw)
  if (!Number.isFinite(value) || value <= 0) return fallback
  return Math.floor(value)
}

export function parsePromoRedeemEnabled(raw: string | undefined): boolean {
  if (!raw?.trim()) return true
  const normalized = raw.trim().toLowerCase()
  if (["0", "false", "no", "off"].includes(normalized)) return false
  return true
}
