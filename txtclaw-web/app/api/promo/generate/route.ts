import { createPromoCode } from "@/lib/promo-codes"
import {
  canUserGeneratePromoCodes,
  getPromoCampaignId,
  getPromoGrantCents,
} from "@/lib/promo-config"
import { auth } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const DEFAULT_GENERATE_COUNT = 10
const MAX_GENERATE_COUNT = 200

type GeneratePayload = {
  count?: number
}

function parseCount(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.min(Math.max(Math.floor(value), 1), MAX_GENERATE_COUNT)
  }

  if (typeof value === "string") {
    const parsed = Number(value)
    if (Number.isFinite(parsed)) {
      return Math.min(Math.max(Math.floor(parsed), 1), MAX_GENERATE_COUNT)
    }
  }

  return DEFAULT_GENERATE_COUNT
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
  const { userId } = await auth()
  if (!userId) {
    return jsonError("Authentication required.", 401)
  }

  if (!canUserGeneratePromoCodes(userId)) {
    return jsonError("Promo code generation is not enabled for this account.", 403)
  }

  const promoCodeSecret = process.env.PROMO_CODE_SECRET?.trim()
  if (!promoCodeSecret) {
    return jsonError("Promo generation is not configured. Missing PROMO_CODE_SECRET.", 500)
  }

  let payload: GeneratePayload = {}
  try {
    payload = (await request.json()) as GeneratePayload
  } catch {
    payload = {}
  }

  const count = parseCount(payload.count)
  const campaignId = getPromoCampaignId()
  const grantCents = getPromoGrantCents()

  const codes: string[] = []
  const seen = new Set<string>()

  while (codes.length < count) {
    const generated = createPromoCode({
      campaignId,
      amountCents: grantCents,
      secret: promoCodeSecret,
    })

    if (seen.has(generated.code)) continue
    seen.add(generated.code)
    codes.push(generated.code)
  }

  return NextResponse.json(
    {
      ok: true,
      count: codes.length,
      campaignId,
      grantCents,
      codes,
      generatedAt: new Date().toISOString(),
    },
    { status: 200 },
  )
}
