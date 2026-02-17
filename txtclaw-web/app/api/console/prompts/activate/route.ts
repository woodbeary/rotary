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

  let payload: { id?: string } | null = null
  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const id = String(payload?.id || "").trim()
  if (!id) return jsonError("Missing id.", 400)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/prompts/activate`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ id }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as {
    ok: boolean
    prompt_version?: unknown
    active_prompt_id?: string
    error?: string
  }
  if (!data.ok || !data.prompt_version) {
    return jsonError(data.error || "Failed to activate prompt.", 502)
  }

  return NextResponse.json(
    { ok: true, promptVersion: data.prompt_version, activePromptId: data.active_prompt_id || null },
    { status: 200 },
  )
}
