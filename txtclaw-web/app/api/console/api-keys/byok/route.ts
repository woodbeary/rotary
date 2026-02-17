import {
  type ApiKeyRecord,
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireVerifiedUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type Ok = { ok: true; record: ApiKeyRecord }

export async function POST(request: NextRequest) {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: {
    keyId?: string
    provider?: "openai_compat" | "openai" | "anthropic"
    apiKey?: string
    baseUrl?: string
    model?: string
    label?: string
  } | null = null

  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const keyId = String(payload?.keyId || "").trim()
  if (!keyId) return jsonError("Missing keyId.", 400)

  const provider = String(payload?.provider || "").trim()
  if (provider !== "openai_compat" && provider !== "openai" && provider !== "anthropic") {
    return jsonError("Missing or invalid provider.", 400)
  }

  const apiKey = String(payload?.apiKey || "").trim()
  if (!apiKey) return jsonError("Missing apiKey.", 400)

  const baseUrlRaw = payload?.baseUrl
  const baseUrl = baseUrlRaw !== undefined && baseUrlRaw !== null ? String(baseUrlRaw).trim() : ""
  const modelRaw = payload?.model
  const model = modelRaw !== undefined && modelRaw !== null ? String(modelRaw).trim() : ""
  const labelRaw = payload?.label
  const label = labelRaw !== undefined && labelRaw !== null ? String(labelRaw).trim() : ""

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/api-keys/byok`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: verified.userId,
      key_id: keyId,
      provider,
      api_key: apiKey,
      ...(baseUrl ? { base_url: baseUrl } : {}),
      ...(model ? { model } : {}),
      ...(label ? { label } : {}),
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as { ok: boolean; record?: ApiKeyRecord; error?: string }
  if (!data.ok || !data.record) {
    return jsonError(data.error || "Failed to set BYOK.", 502)
  }

  const out: Ok = { ok: true, record: data.record }
  return NextResponse.json(out, { status: 200 })
}
