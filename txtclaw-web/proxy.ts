import { CLERK_ENABLED } from "@/lib/clerk-config"
import type { NextFetchEvent, NextRequest } from "next/server"
import { NextResponse } from "next/server"

export default async function middleware(request: NextRequest, event: NextFetchEvent) {
  if (!CLERK_ENABLED) return NextResponse.next()

  const { clerkMiddleware } = await import("@clerk/nextjs/server")
  const handler = clerkMiddleware()
  return handler(request, event)
}

export const config = {
  matcher: [
    "/((?!_next|api/cron/waitlist-invite|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)",
  ],
}
