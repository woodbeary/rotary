import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireAdminUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function POST(request: NextRequest) {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: { traceId?: string; grade?: string; note?: string } | null = null
  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const traceId = String(payload?.traceId || "").trim()
  const grade = String(payload?.grade || "").trim()
  const note =
    payload?.note !== undefined && payload?.note !== null ? String(payload.note).trim() : ""
  if (!traceId) return jsonError("Missing traceId.", 400)
  if (!grade) return jsonError("Missing grade.", 400)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/traces/grade`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      trace_id: traceId,
      grade,
      ...(note ? { note } : {}),
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as { ok: boolean; trace?: unknown; error?: string }
  if (!data.ok || !data.trace) {
    return jsonError(data.error || "Failed to grade trace.", 502)
  }

  return NextResponse.json({ ok: true, trace: data.trace }, { status: 200 })
}
