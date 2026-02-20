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
  const limit = String(searchParams.get("limit") || "50").trim()
  const cursor = String(searchParams.get("cursor") || "").trim()
  const status = String(searchParams.get("status") || "").trim()
  const search = String(searchParams.get("search") || "").trim()

  const qs = new URLSearchParams()
  if (limit) qs.set("limit", limit)
  if (cursor) qs.set("cursor", cursor)
  if (status) qs.set("status", status)
  if (search) qs.set("search", search)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/compliance/actors?${qs.toString()}`, {
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
    actors?: unknown[]
    cursor?: string | null
    error?: string
  }
  if (!data.ok) {
    return jsonError(data.error || "Failed to load actors.", 502)
  }

  return NextResponse.json(
    {
      ok: true,
      actors: data.actors || [],
      cursor: data.cursor ?? null,
    },
    { status: 200 },
  )
}
