import {
  type ApiKeyRecord,
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requirePaidDevApiUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type Ok = { ok: true; record: ApiKeyRecord }

export async function POST(request: NextRequest) {
  const paid = await requirePaidDevApiUserId()
  if (!paid.ok) return paid.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: { keyId?: string } | null = null
  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const keyId = String(payload?.keyId || "").trim()
  if (!keyId) return jsonError("Missing keyId.", 400)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/api-keys/byok/clear`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: paid.userId,
      key_id: keyId,
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as { ok: boolean; record?: ApiKeyRecord; error?: string }
  if (!data.ok || !data.record) {
    return jsonError(data.error || "Failed to clear BYOK.", 502)
  }

  const out: Ok = { ok: true, record: data.record }
  return NextResponse.json(out, { status: 200 })
}
