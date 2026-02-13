import { clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"
import { checkRateLimit, getClientIp } from "@/lib/rate-limit"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type JoinPayload = {
  email?: string
  source?: string
}

const WAITLIST_JOIN_RATE_LIMIT = 8
const WAITLIST_JOIN_RATE_WINDOW_MS = 60_000

function normalizeEmail(value: string) {
  return value.trim().toLowerCase()
}

function isValidEmail(email: string) {
  return /\S+@\S+\.\S+/.test(email)
}

export async function POST(request: NextRequest) {
  const ip = getClientIp(request)
  const rate = checkRateLimit({
    key: `waitlist-join:${ip}`,
    limit: WAITLIST_JOIN_RATE_LIMIT,
    windowMs: WAITLIST_JOIN_RATE_WINDOW_MS,
  })

  if (!rate.allowed) {
    return NextResponse.json(
      { ok: false, error: "Too many attempts. Please wait a minute and retry." },
      {
        status: 429,
        headers: {
          "Retry-After": Math.max(
            1,
            Math.ceil((rate.resetAt - Date.now()) / 1000)
          ).toString(),
        },
      }
    )
  }

  let payload: JoinPayload

  try {
    payload = (await request.json()) as JoinPayload
  } catch {
    return NextResponse.json(
      { ok: false, error: "Invalid JSON body." },
      { status: 400 }
    )
  }

  const email = normalizeEmail(payload.email || "")
  if (!email || !isValidEmail(email)) {
    return NextResponse.json(
      { ok: false, error: "Please enter a valid email address." },
      { status: 400 }
    )
  }

  try {
    const client = await clerkClient()
    const entry = await client.waitlistEntries.create({
      emailAddress: email,
      notify: false,
    })

    return NextResponse.json(
      {
        ok: true,
        id: entry.id,
        status: entry.status,
        source: payload.source || "unknown",
      },
      { status: 200 }
    )
  } catch (error) {
    // Duplicate-safe fallback: treat existing pending/invited entries as success.
    try {
      const client = await clerkClient()
      const existing = await client.waitlistEntries.list({
        query: email,
        limit: 5,
      })
      const matched = existing.data.find(
        (entry) => normalizeEmail(entry.emailAddress) === email
      )
      if (matched) {
        return NextResponse.json(
          {
            ok: true,
            alreadyJoined: true,
            id: matched.id,
            status: matched.status,
            source: payload.source || "unknown",
          },
          { status: 200 }
        )
      }
    } catch {
      // ignore lookup failure and fall through to error response.
    }

    return NextResponse.json(
      {
        ok: false,
        error:
          error instanceof Error
            ? error.message
            : "Could not join waitlist right now.",
      },
      { status: 500 }
    )
  }
}
