import { clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type JoinPayload = {
  email?: string
  source?: string
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase()
}

function isValidEmail(email: string) {
  return /\S+@\S+\.\S+/.test(email)
}

export async function POST(request: NextRequest) {
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

