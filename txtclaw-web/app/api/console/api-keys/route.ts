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

type ListOk = { ok: true; apiKeys: ApiKeyRecord[] }
type CreateOk = { ok: true; apiKey: string; record: ApiKeyRecord }

export async function GET() {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  const baseUrl = getConsoleBaseUrl()
  const url = `${baseUrl.replace(/\/+$/, "")}/console/v1/api-keys?user_id=${encodeURIComponent(
    verified.userId,
  )}`

  const init: RequestInit = {
    method: "GET",
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  }

  let res = await fetch(url, init)
  let text = await res.text()
  // Cloudflare DO cold start / transient errors happen in practice. One retry keeps console UX stable.
  if (!res.ok && res.status >= 500) {
    await new Promise((r) => setTimeout(r, 150))
    res = await fetch(url, init)
    text = await res.text()
  }
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as { ok: boolean; api_keys?: ApiKeyRecord[]; error?: string }
  if (!data.ok) {
    return jsonError(data.error || "Failed to list API keys.", 502)
  }

  const payload: ListOk = { ok: true, apiKeys: data.api_keys || [] }
  return NextResponse.json(payload, { status: 200 })
}

export async function POST(request: NextRequest) {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: { label?: string } = {}
  try {
    payload = (await request.json()) as { label?: string }
  } catch {
    payload = {}
  }

  const baseUrl = getConsoleBaseUrl()
  const url = `${baseUrl.replace(/\/+$/, "")}/console/v1/api-keys`
  const body = JSON.stringify({
    user_id: verified.userId,
    label: payload.label,
  })

  const init: RequestInit = {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body,
  }

  let res = await fetch(url, init)
  let text = await res.text()
  if (!res.ok && res.status >= 500) {
    await new Promise((r) => setTimeout(r, 150))
    res = await fetch(url, init)
    text = await res.text()
  }
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as {
    ok: boolean
    api_key?: string
    record?: ApiKeyRecord
    error?: string
  }
  if (!data.ok || !data.api_key || !data.record) {
    return jsonError(data.error || "Failed to create API key.", 502)
  }

  const out: CreateOk = {
    ok: true,
    apiKey: data.api_key,
    record: data.record,
  }

  return NextResponse.json(out, { status: 200 })
}
