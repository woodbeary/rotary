import { getConsoleBaseUrl, getConsoleServiceToken, jsonError } from "@/app/api/console/_shared"
import { auth } from "@clerk/nextjs/server"
import { NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type ApiUserPlan = {
  userId: string
  plan: "free" | "pro" | "max" | "byok"
  provider?: "square" | "manual"
  offerCode?: string
  paidAt?: string
  updatedAt: string
}

export async function GET() {
  const { userId } = await auth()
  if (!userId) return jsonError("Authentication required.", 401)

  const token = getConsoleServiceToken()
  if (!token) return jsonError("Missing TXTCLAW_CONSOLE_SERVICE_TOKEN.", 500)

  const baseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  const res = await fetch(`${baseUrl}/console/v1/plan?user_id=${encodeURIComponent(userId)}`, {
    method: "GET",
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })

  const text = await res.text().catch(() => "")
  if (!res.ok) return jsonError(`Console error (${res.status}): ${text}`, 502)

  const data = JSON.parse(text) as { ok: boolean; plan?: ApiUserPlan; error?: string }
  if (!data.ok || !data.plan) {
    return jsonError(data.error || "Failed to load plan.", 502)
  }

  return NextResponse.json({ ok: true, plan: data.plan }, { status: 200 })
}
