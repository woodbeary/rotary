import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireAdminUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET(
  _request: NextRequest,
  context: { params: Promise<{ traceId: string }> },
) {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  const params = await context.params
  const traceId = String(params.traceId || "").trim()
  if (!traceId) return jsonError("Missing traceId.", 400)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/traces/${encodeURIComponent(traceId)}`, {
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

  const data = JSON.parse(text) as { ok: boolean; trace?: unknown; error?: string }
  if (!data.ok || !data.trace) {
    return jsonError(data.error || "Failed to load trace.", 502)
  }

  return NextResponse.json({ ok: true, trace: data.trace }, { status: 200 })
}
