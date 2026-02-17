import {
  getConsoleBaseUrl,
  getConsoleServiceToken,
  jsonError,
  requireAdminUserId,
} from "@/app/api/console/_shared"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET() {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/prompts`, {
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
    prompt_versions?: unknown[]
    active_prompt_id?: string | null
    error?: string
  }
  if (!data.ok) {
    return jsonError(data.error || "Failed to list prompts.", 502)
  }

  return NextResponse.json(
    {
      ok: true,
      promptVersions: data.prompt_versions || [],
      activePromptId: data.active_prompt_id ?? null,
    },
    { status: 200 },
  )
}

export async function POST(request: NextRequest) {
  const admin = await requireAdminUserId()
  if (!admin.ok) return admin.response

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  let payload: { label?: string; content?: string; activate?: boolean } | null = null
  try {
    payload = (await request.json()) as any
  } catch {
    payload = null
  }

  const label = typeof payload?.label === "string" ? payload.label.trim() : ""
  const content = typeof payload?.content === "string" ? payload.content.trim() : ""
  const activate = payload?.activate !== false
  if (!content) return jsonError("Missing content.", 400)

  const workerBaseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${workerBaseUrl}/console/v1/prompts`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      ...(label ? { label } : {}),
      content,
      activate,
    }),
  })

  const text = await res.text()
  if (!res.ok) {
    return jsonError(`Console error (${res.status}): ${text}`, 502)
  }

  const data = JSON.parse(text) as {
    ok: boolean
    prompt_version?: unknown
    active_prompt_id?: string | null
    error?: string
  }
  if (!data.ok || !data.prompt_version) {
    return jsonError(data.error || "Failed to create prompt.", 502)
  }

  return NextResponse.json(
    { ok: true, promptVersion: data.prompt_version, activePromptId: data.active_prompt_id ?? null },
    { status: 200 },
  )
}
