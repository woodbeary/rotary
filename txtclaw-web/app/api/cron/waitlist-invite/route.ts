import { clerkClient } from "@clerk/nextjs/server"
import { NextRequest, NextResponse } from "next/server"

const DEFAULT_INVITE_BATCH_SIZE = 25
const MAX_INVITE_BATCH_SIZE = 200

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

type InviteFailure = {
  id: string
  reason: string
}

function parseInviteBatchSize() {
  const raw = process.env.WAITLIST_INVITES_PER_HOUR?.trim()
  if (!raw) return DEFAULT_INVITE_BATCH_SIZE

  const parsed = Number(raw)
  if (!Number.isFinite(parsed)) return DEFAULT_INVITE_BATCH_SIZE

  return Math.min(Math.max(Math.floor(parsed), 1), MAX_INVITE_BATCH_SIZE)
}

function getRequestBearerToken(request: NextRequest) {
  const header = request.headers.get("authorization")?.trim()
  if (!header?.startsWith("Bearer ")) return null
  return header.slice("Bearer ".length).trim()
}

function isAuthorizedCronRequest(request: NextRequest) {
  const expectedSecret =
    process.env.WAITLIST_CRON_SECRET?.trim() || process.env.CRON_SECRET?.trim()

  if (!expectedSecret) return false

  const requestSecret = getRequestBearerToken(request)
  return Boolean(requestSecret && requestSecret === expectedSecret)
}

function toErrorMessage(error: unknown) {
  if (error instanceof Error) return error.message
  return "Unknown invite error"
}

async function runWaitlistInviteBatch(request: NextRequest) {
  const dryRun = request.nextUrl.searchParams.get("dryRun") === "1"
  const batchSize = parseInviteBatchSize()
  const client = await clerkClient()

  const pending = await client.waitlistEntries.list({
    status: "pending",
    orderBy: "+created_at",
    limit: batchSize,
  })

  const entries = pending.data

  if (dryRun) {
    return NextResponse.json(
      {
        ok: true,
        dryRun: true,
        batchSize,
        pendingCount: pending.totalCount ?? entries.length,
        selectedCount: entries.length,
        selectedEntryIds: entries.map((entry) => entry.id),
      },
      { status: 200 }
    )
  }

  let invitedCount = 0
  const failed: InviteFailure[] = []

  for (const entry of entries) {
    try {
      await client.waitlistEntries.invite(entry.id, {
        ignoreExisting: true,
      })
      invitedCount += 1
    } catch (error) {
      failed.push({
        id: entry.id,
        reason: toErrorMessage(error),
      })
    }
  }

  const status = failed.length > 0 ? 207 : 200

  return NextResponse.json(
    {
      ok: failed.length === 0,
      dryRun: false,
      batchSize,
      selectedCount: entries.length,
      invitedCount,
      failedCount: failed.length,
      failures: failed,
    },
    { status }
  )
}

function getMissingSecretResponse() {
  return NextResponse.json(
    {
      ok: false,
      error:
        "Missing waitlist cron secret. Set WAITLIST_CRON_SECRET or CRON_SECRET in environment variables.",
    },
    { status: 500 }
  )
}

function getUnauthorizedResponse() {
  return NextResponse.json(
    {
      ok: false,
      error: "Unauthorized cron request.",
    },
    { status: 401 }
  )
}

export async function GET(request: NextRequest) {
  const hasConfiguredSecret =
    Boolean(process.env.WAITLIST_CRON_SECRET?.trim()) ||
    Boolean(process.env.CRON_SECRET?.trim())

  if (!hasConfiguredSecret) return getMissingSecretResponse()
  if (!isAuthorizedCronRequest(request)) return getUnauthorizedResponse()

  try {
    return await runWaitlistInviteBatch(request)
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: "Failed to process waitlist invite batch.",
        detail: toErrorMessage(error),
      },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  const hasConfiguredSecret =
    Boolean(process.env.WAITLIST_CRON_SECRET?.trim()) ||
    Boolean(process.env.CRON_SECRET?.trim())

  if (!hasConfiguredSecret) return getMissingSecretResponse()
  if (!isAuthorizedCronRequest(request)) return getUnauthorizedResponse()

  try {
    return await runWaitlistInviteBatch(request)
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: "Failed to process waitlist invite batch.",
        detail: toErrorMessage(error),
      },
      { status: 500 }
    )
  }
}
