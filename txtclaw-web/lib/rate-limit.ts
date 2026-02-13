import type { NextRequest } from "next/server"

type Bucket = {
  count: number
  resetAt: number
}

type Store = Map<string, Bucket>

declare global {
  // eslint-disable-next-line no-var
  var __txtclawRateLimitStore: Store | undefined
}

function getStore(): Store {
  if (!globalThis.__txtclawRateLimitStore) {
    globalThis.__txtclawRateLimitStore = new Map<string, Bucket>()
  }
  return globalThis.__txtclawRateLimitStore
}

export function getClientIp(request: NextRequest): string {
  const forwardedFor = request.headers.get("x-forwarded-for")
  if (forwardedFor) {
    const first = forwardedFor.split(",")[0]?.trim()
    if (first) return first
  }

  const realIp = request.headers.get("x-real-ip")?.trim()
  if (realIp) return realIp

  return "unknown"
}

export function checkRateLimit(args: {
  key: string
  limit: number
  windowMs: number
}): {
  allowed: boolean
  remaining: number
  resetAt: number
} {
  const now = Date.now()
  const store = getStore()
  const existing = store.get(args.key)

  if (!existing || now >= existing.resetAt) {
    const resetAt = now + args.windowMs
    store.set(args.key, { count: 1, resetAt })
    return {
      allowed: true,
      remaining: Math.max(args.limit - 1, 0),
      resetAt,
    }
  }

  if (existing.count >= args.limit) {
    return {
      allowed: false,
      remaining: 0,
      resetAt: existing.resetAt,
    }
  }

  existing.count += 1
  store.set(args.key, existing)

  return {
    allowed: true,
    remaining: Math.max(args.limit - existing.count, 0),
    resetAt: existing.resetAt,
  }
}
