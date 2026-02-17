import { isAdminUserId } from "@/lib/admin"
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
