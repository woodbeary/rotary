import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireAdminUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET(request: NextRequest) {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  const { searchParams } = new URL(request.url)
  const limit = String(searchParams.get("limit") || "").trim()
  const cursor = String(searchParams.get("cursor") || "").trim()

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const qs = new URLSearchParams()
  if (limit) qs.set("limit", limit)
  if (cursor) qs.set("cursor", cursor)

  const res = await fetch(`${workerBaseUrl}/console/v1/traces?${qs.toString()}`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
    },
    cache: "no-store",
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as {
    ok: boolean
    traces?: unknown[]
    cursor?: string | null
    error?: string
  }
  if (!data.ok) {
    return jsonError(data.error || "Failed to list traces.", 502)
  }

  return NextResponse.json(
    { ok: true, traces: data.traces || [], cursor: data.cursor ?? null },
    { status: 200 },
  )
}
