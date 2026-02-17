import { ConsoleShell } from "@/components/console-shell"
import { isAdminUserId } from "@/lib/admin"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { auth } from "@clerk/nextjs/server"
import { redirect } from "next/navigation"
import type { ReactNode } from "react"

export const dynamic = "force-dynamic"

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  if (!CLERK_ENABLED) {
    return (
      <main className="min-h-screen bg-background">
        <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <h1 className="font-mono text-2xl font-semibold text-foreground">Dashboard</h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Clerk auth is not configured in this environment.
            </p>
          </div>
        </div>
      </main>
    )
  }

  const { userId } = await auth()
  if (!userId) {
    redirect("/sign-in")
  }

  return <ConsoleShell isAdmin={isAdminUserId(userId)}>{children}</ConsoleShell>
}
