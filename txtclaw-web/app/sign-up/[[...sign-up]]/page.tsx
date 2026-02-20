"use client"

import { CLERK_ENABLED } from "@/lib/clerk-config"
import { SignUp } from "@clerk/nextjs"
import { ArrowLeft } from "lucide-react"
import Link from "next/link"

export default function SignUpPage() {
  if (!CLERK_ENABLED) {
    return (
      <main className="min-h-screen bg-background">
        <div className="mx-auto max-w-3xl px-6 py-16 md:py-24">
          <div className="rounded-2xl border border-border/60 bg-card p-8">
            <h1 className="text-2xl font-semibold text-foreground">Sign up</h1>
            <p className="mt-3 text-sm text-muted-foreground">
              Clerk auth is not configured in this environment.
            </p>
            <Link
              href="/"
              className="mt-6 inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              Back home
            </Link>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-4xl px-6 py-12 md:py-20">
        <Link
          href="/"
          className="mb-8 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to home
        </Link>

        <div className="flex justify-center">
          <SignUp
            routing="path"
            path="/sign-up"
            signInUrl="/sign-in"
            afterSignUpUrl="/dashboard/billing"
          />
        </div>
      </div>
    </main>
  )
}
