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
  const actorId = String(searchParams.get("actor_id") || "").trim()
  const kind = String(searchParams.get("kind") || "").trim()
  const limit = String(searchParams.get("limit") || "50").trim()
  const cursor = String(searchParams.get("cursor") || "").trim()

  if (!actorId) return jsonError("Missing actor_id.", 400)

  const qs = new URLSearchParams()
  qs.set("actor_id", actorId)
  qs.set("limit", limit)
  if (kind) qs.set("kind", kind)
  if (cursor) qs.set("cursor", cursor)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/compliance/actors/events?${qs.toString()}`, {
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
    events?: unknown[]
    cursor?: string | null
    error?: string
  }

  if (!data.ok) {
    return jsonError(data.error || "Failed to load actor events.", 502)
  }

  return NextResponse.json(
    {
      ok: true,
      events: data.events || [],
      cursor: data.cursor ?? null,
    },
    { status: 200 },
  )
}
