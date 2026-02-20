import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireAdminUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

type ComplianceAction =
  | "warn_actor"
  | "pause_actor_egress"
  | "disable_actor_numbers"
  | "unfreeze_actor"

const ALLOWED_ACTIONS = new Set<ComplianceAction>([
  "warn_actor",
  "pause_actor_egress",
  "disable_actor_numbers",
  "unfreeze_actor",
])

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function POST(request: NextRequest) {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: {
    actorId?: string
    action?: ComplianceAction
    reason?: string
    durationMinutes?: number
  } | null = null

  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const actorId = String(payload?.actorId || "").trim()
  const action = payload?.action
  const reason = String(payload?.reason || "").trim() || null
  const durationMinutes =
    typeof payload?.durationMinutes === "number" && Number.isFinite(payload.durationMinutes)
      ? payload.durationMinutes
      : null

  if (!actorId) return jsonError("Missing actorId.", 400)
  if (!action || !ALLOWED_ACTIONS.has(action)) {
    return jsonError("Invalid action.", 400)
  }
  if (!reason) {
    return jsonError("Missing reason.", 400)
  }
  if (action === "pause_actor_egress" && (durationMinutes === null || durationMinutes <= 0)) {
    return jsonError("pause_actor_egress requires a positive duration_minutes.", 400)
  }

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const body = {
    actor_id: actorId,
    action,
    reason,
    ...(durationMinutes !== null ? { duration_minutes: durationMinutes } : {}),
  }

  const res = await fetch(`${workerBaseUrl}/console/v1/compliance/actors/action`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as {
    ok: boolean
    actor?: unknown
    action?: ComplianceAction
    action_id?: string
    actionId?: string
    error?: string
  }

  if (!data.ok) {
    return jsonError(data.error || "Failed to apply compliance action.", 502)
  }

  return NextResponse.json(
    {
      ok: true,
      actor: data.actor || null,
      action: data.action || action,
      actionId: data.action_id || data.actionId || null,
    },
    { status: 200 },
  )
}
