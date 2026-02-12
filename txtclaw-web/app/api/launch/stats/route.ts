import { clerkClient, type User } from "@clerk/nextjs/server"
import { NextResponse } from "next/server"
import { collectLaunchStats } from "@/lib/billing"

export const runtime = "nodejs"
export const dynamic = "force-dynamic"

const LIST_USERS_PAGE_SIZE = 100
const LIST_USERS_MAX = 2000

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

export async function GET() {
  try {
    const client = await clerkClient()
    const users = await listUsers(client)
    const stats = collectLaunchStats(users)

    return NextResponse.json(
      {
        ok: true,
        earlyBirdClaimed: stats.earlyBirdClaimed,
        earlyBirdCap: stats.earlyBirdCap,
        ltdClaimed: stats.ltdClaimed,
        ltdCap: stats.ltdCap,
        recentPaid: stats.recentPaid,
      },
      { status: 200 }
    )
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error:
          error instanceof Error
            ? error.message
            : "Failed to load launch stats.",
      },
      { status: 500 }
    )
  }
}
