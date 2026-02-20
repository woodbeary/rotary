import { isAdminUserId } from "@/lib/admin"
import { getBillingMetadata, getUserOfferCode } from "@/lib/billing"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { getConsoleBaseUrl as getConsoleBaseUrlFromEnv } from "@/lib/txtclaw-urls"
import { auth, clerkClient } from "@clerk/nextjs/server"
import { NextResponse } from "next/server"

export type ApiKeyRecord = {
  keyId: string
  prefix: string
  label?: string
  createdAt: string
  revokedAt?: string
  lastUsedAt?: string
  byokConfigured?: boolean
  byokProvider?: string
  byokUpdatedAt?: string
  byokFingerprint?: string
}

export type ApiUserPlan = {
  userId: string
  plan: "free" | "pro" | "max" | "byok"
  provider?: "square" | "manual"
  offerCode?: string
  paidAt?: string
  updatedAt: string
}

export function jsonError(message: string, status: number) {
  return NextResponse.json({ ok: false, error: message }, { status })
}

export function getConsoleBaseUrl(): string {
  return getConsoleBaseUrlFromEnv()
}

export function getConsoleServiceToken(): string | null {
  const value = process.env.TXTCLAW_CONSOLE_SERVICE_TOKEN?.trim()
  return value ? value : null
}

export async function maybeSyncWorkerPlanFromClerk(args: {
  userId: string
}): Promise<{ ok: true; synced: boolean } | { ok: false; status: number; error: string }> {
  if (!CLERK_ENABLED) return { ok: true, synced: false }

  const token = getConsoleServiceToken()
  if (!token) {
    return { ok: false, status: 500, error: "Missing TXTCLAW_CONSOLE_SERVICE_TOKEN." }
  }

  const baseUrl = getConsoleBaseUrl().replace(/\/+$/, "")

  try {
    const client: any =
      typeof (clerkClient as any) === "function"
        ? await (clerkClient as any)()
        : (clerkClient as any)

    const user = await client.users.getUser(args.userId)
    const billing = getBillingMetadata(user)
    const offerCode = getUserOfferCode(user)

    // Nothing to sync unless we have evidence of a successful payment.
    if (!billing.paidAt || !offerCode) return { ok: true, synced: false }

    const res = await fetch(`${baseUrl}/console/v1/plan/sync`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: args.userId,
        offer_code: offerCode,
        paid_at: billing.paidAt,
      }),
    })

    const text = await res.text().catch(() => "")
    if (!res.ok) {
      return {
        ok: false,
        status: 502,
        error: `Worker plan sync failed (${res.status}): ${text}`,
      }
    }

    const json = text ? (JSON.parse(text) as any) : null
    if (!json?.ok) {
      return {
        ok: false,
        status: 502,
        error: `Worker plan sync rejected: ${text || "invalid JSON"}`,
      }
    }

    return { ok: true, synced: true }
  } catch (error) {
    return {
      ok: false,
      status: 502,
      error: error instanceof Error ? error.message : "Worker plan sync failed.",
    }
  }
}

export async function fetchApiUserPlan(args: {
  userId: string
}): Promise<{ ok: true; plan: ApiUserPlan } | { ok: false; status: number; error: string }> {
  const token = getConsoleServiceToken()
  if (!token) {
    return { ok: false, status: 500, error: "Missing TXTCLAW_CONSOLE_SERVICE_TOKEN." }
  }

  const baseUrl = getConsoleBaseUrl().replace(/\/+$/, "")
  try {
    const res = await fetch(
      `${baseUrl}/console/v1/plan?user_id=${encodeURIComponent(args.userId)}`,
      {
        method: "GET",
        headers: { Authorization: `Bearer ${token}` },
        cache: "no-store",
      },
    )

    const text = await res.text().catch(() => "")
    if (!res.ok) {
      return { ok: false, status: 502, error: `Console error (${res.status}): ${text}` }
    }

    const data = JSON.parse(text) as { ok: boolean; plan?: ApiUserPlan | null; error?: string }
    if (!data.ok) {
      return { ok: false, status: 502, error: data.error || "Failed to load plan." }
    }

    const plan: ApiUserPlan = data.plan || {
      userId: args.userId,
      plan: "free",
      provider: undefined,
      offerCode: undefined,
      paidAt: undefined,
      updatedAt: new Date().toISOString(),
    }

    return { ok: true, plan }
  } catch (error) {
    return {
      ok: false,
      status: 502,
      error: error instanceof Error ? error.message : "Failed to load plan.",
    }
  }
}

function getUserPrimaryEmailVerified(user: unknown): boolean {
  const u = user as {
    primaryEmailAddressId?: string | null
    emailAddresses?: Array<{
      id?: string | null
      verification?: { status?: string | null } | null
    }> | null
  }

  const emails = u.emailAddresses || []
  const primary = emails.find((email) => email.id === u.primaryEmailAddressId) || emails[0]
  const status = primary?.verification?.status || ""
  return String(status).toLowerCase() === "verified"
}

export async function requireVerifiedUserId() {
  if (!CLERK_ENABLED) {
    return {
      ok: false as const,
      response: jsonError("Clerk is not configured.", 503),
    }
  }

  const { userId } = await auth()
  if (!userId) {
    return {
      ok: false as const,
      response: jsonError("Authentication required.", 401),
    }
  }

  const client: any =
    typeof (clerkClient as any) === "function" ? await (clerkClient as any)() : (clerkClient as any)

  const user = await client.users.getUser(userId)
  if (!getUserPrimaryEmailVerified(user)) {
    return {
      ok: false as const,
      response: jsonError("Email verification required.", 403),
    }
  }

  return { ok: true as const, userId }
}

export async function requirePaidDevApiUserId() {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified

  const planRes = await fetchApiUserPlan({ userId: verified.userId })
  if (!planRes.ok) {
    return {
      ok: false as const,
      response: jsonError(planRes.error, planRes.status),
    }
  }

  if (planRes.plan.plan === "free") {
    const sync = await maybeSyncWorkerPlanFromClerk({ userId: verified.userId })
    if (!sync.ok) {
      return { ok: false as const, response: jsonError(sync.error, sync.status) }
    }

    if (sync.synced) {
      const resynced = await fetchApiUserPlan({ userId: verified.userId })
      if (!resynced.ok) {
        return { ok: false as const, response: jsonError(resynced.error, resynced.status) }
      }

      if (resynced.plan.plan !== "free") {
        return { ok: true as const, userId: verified.userId, plan: resynced.plan }
      }
    }

    return {
      ok: false as const,
      response: jsonError(
        "Dev API subscription required. Visit /dashboard/billing to activate your account.",
        402,
      ),
    }
  }

  return { ok: true as const, userId: verified.userId, plan: planRes.plan }
}

export async function requireAdminUserId() {
  const verified = await requireVerifiedUserId()
  if (!verified.ok) return verified

  if (!isAdminUserId(verified.userId)) {
    return {
      ok: false as const,
      response: jsonError("Admin access required.", 403),
    }
  }

  return verified
}
