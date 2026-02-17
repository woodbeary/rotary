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

export async function POST(request: NextRequest) {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: { keyId?: string } | null = null
  try {
    payload = (await request.json()) as { keyId?: string }
  } catch {
    payload = null
  }

  const keyId = String(payload?.keyId || "").trim()
  if (!keyId) return jsonError("Missing keyId.", 400)

  const baseUrl = getConsoleBaseUrl()
  const res = await fetch(`${baseUrl.replace(/\/+$/, "")}/console/v1/api-keys/revoke`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      user_id: verified.userId,
      key_id: keyId,
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as { ok: boolean; record?: ApiKeyRecord; error?: string }
  if (!data.ok || !data.record) {
    return jsonError(data.error || "Failed to revoke API key.", 502)
  }

  return NextResponse.json({ ok: true, record: data.record }, { status: 200 })
}
