import {
  fetchApiUserPlan,
  jsonError,
  maybeSyncWorkerPlanFromClerk,
} from "@/app/api/console/_shared"
import { auth } from "@clerk/nextjs/server"
import { NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

export async function GET() {
  const { userId } = await auth()
  if (!userId) return jsonError("Authentication required.", 401)

  let planRes = await fetchApiUserPlan({ userId })
  if (!planRes.ok) return jsonError(planRes.error, planRes.status)

  if (planRes.plan.plan === "free") {
    const sync = await maybeSyncWorkerPlanFromClerk({ userId })
    if (!sync.ok) return jsonError(sync.error, sync.status)
    if (sync.synced) {
      planRes = await fetchApiUserPlan({ userId })
      if (!planRes.ok) return jsonError(planRes.error, planRes.status)
    }
  }

  return NextResponse.json({ ok: true, plan: planRes.plan }, { status: 200 })
}
