import { collectLaunchStats } from "@/lib/billing"
import { checkRateLimit, getClientIp } from "@/lib/rate-limit"
import { type User, clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000
const STATS_CACHE_TTL_MS = 30_000
const STATS_RATE_LIMIT = 60
const STATS_RATE_LIMIT_WINDOW_MS = 60_000

type CachedStatsPayload = {
  ok: true
  earlyBirdClaimed: number
  earlyBirdCap: number
  ltdClaimed: number
  ltdCap: number
  recentPaid: ReturnType<typeof collectLaunchStats>["recentPaid"]
  waitlistCount: number
}

let cachedStats: { expiresAt: number; payload: CachedStatsPayload } | null = null

async function listUsers(client: Awaited<ReturnType<typeof clerkClient>>): Promise<User[]> {
  const users: User[] = []
  let offset = 0

  while (offset < LIST_USERS_MAX) {
    const page = await client.users.getUserList({
      limit: LIST_USERS_PAGE_SIZE,
      offset,
      orderBy: "+created_at",
    })

    const batch = page.data || []
    users.push(...batch)

    if (batch.length < LIST_USERS_PAGE_SIZE) break
    offset += batch.length
  }

  return users
}

async function countWaitlistEntries(
  client: Awaited<ReturnType<typeof clerkClient>>,
): Promise<number> {
  const page = await client.waitlistEntries.list({ limit: 1 })
  const withMeta = page as unknown as {
    totalCount?: number
    data?: Array<unknown>
  }

  if (typeof withMeta.totalCount === "number") {
    return Math.max(withMeta.totalCount, 0)
  }

  return Array.isArray(withMeta.data) ? withMeta.data.length : 0
}

export async function GET(request: NextRequest) {
  try {
    const ip = getClientIp(request)
    const rate = checkRateLimit({
      key: `launch-stats:${ip}`,
      limit: STATS_RATE_LIMIT,
      windowMs: STATS_RATE_LIMIT_WINDOW_MS,
    })

    if (!rate.allowed) {
      return NextResponse.json(
        { ok: false, error: "Too many requests. Try again shortly." },
        {
          status: 429,
          headers: {
            "Retry-After": Math.max(1, Math.ceil((rate.resetAt - Date.now()) / 1000)).toString(),
          },
        },
      )
    }

    if (cachedStats && Date.now() < cachedStats.expiresAt) {
      return NextResponse.json(cachedStats.payload, {
        status: 200,
        headers: {
          "Cache-Control": "public, s-maxage=30, stale-while-revalidate=60",
        },
      })
    }

    const client = await clerkClient()
    const [users, waitlistCount] = await Promise.all([
      listUsers(client),
      countWaitlistEntries(client),
    ])
    const stats = collectLaunchStats(users)
    const payload: CachedStatsPayload = {
      ok: true,
      earlyBirdClaimed: stats.earlyBirdClaimed,
      earlyBirdCap: stats.earlyBirdCap,
      ltdClaimed: stats.ltdClaimed,
      ltdCap: stats.ltdCap,
      recentPaid: stats.recentPaid,
      waitlistCount,
    }
    cachedStats = {
      payload,
      expiresAt: Date.now() + STATS_CACHE_TTL_MS,
    }

    return NextResponse.json(payload, {
      status: 200,
      headers: {
        "Cache-Control": "public, s-maxage=30, stale-while-revalidate=60",
      },
    })
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Failed to load launch stats.",
      },
      { status: 500 },
    )
  }
}
