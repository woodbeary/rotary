"use client"

import { FormEvent, useEffect, useMemo, useState } from "react"
import { ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  isWaitlistMarkedJoinedInBrowser,
  markWaitlistJoinedInBrowser,
} from "@/lib/waitlist"
import { cn } from "@/lib/utils"

type WaitlistInlineFormProps = {
  source?: string
  className?: string
}

function normalizeEmail(value: string) {
  return value.trim().toLowerCase()
}

export function WaitlistInlineForm({
  source = "inline_waitlist",
  className,
}: WaitlistInlineFormProps) {
  const [email, setEmail] = useState("")
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [submitted, setSubmitted] = useState(false)

  const normalizedEmail = useMemo(() => normalizeEmail(email), [email])
  const emailLooksValid = /\S+@\S+\.\S+/.test(normalizedEmail)

  useEffect(() => {
    const syncJoinedState = () => {
      setSubmitted(isWaitlistMarkedJoinedInBrowser())
    }

    syncJoinedState()
    window.addEventListener("storage", syncJoinedState)
    window.addEventListener("txtclaw:waitlist-joined", syncJoinedState)

    return () => {
      window.removeEventListener("storage", syncJoinedState)
      window.removeEventListener("txtclaw:waitlist-joined", syncJoinedState)
    }
  }, [])

  const onSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!emailLooksValid || submitting || submitted) return

    setSubmitting(true)
    setError(null)
    try {
      const response = await fetch("/api/waitlist/join", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: normalizedEmail,
          source,
        }),
      })

      const payload = (await response.json().catch(() => null)) as
        | { ok?: boolean; error?: string }
        | null

      if (!response.ok || !payload?.ok) {
        throw new Error(payload?.error || "Unable to join waitlist.")
      }

      markWaitlistJoinedInBrowser()
      window.dispatchEvent(new Event("txtclaw:waitlist-joined"))
      setSubmitted(true)
    } catch (submitError) {
      setError(
        submitError instanceof Error
          ? submitError.message
          : "Unable to join waitlist."
      )
    } finally {
      setSubmitting(false)
    }
  }

  if (submitted) {
    return (
      <div
        className={cn(
          "w-full rounded-xl border border-emerald-500/40 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-700 dark:text-emerald-200 sm:max-w-xl",
          className
        )}
      >
        You&apos;re on the Apple beta list. We&apos;ll invite in staged batches.
      </div>
    )
  }

  return (
    <form
      className={cn("w-full space-y-2 sm:max-w-xl", className)}
      onSubmit={onSubmit}
    >
      <div className="flex w-full flex-col gap-2 sm:flex-row sm:items-center">
        <Input
          type="email"
          autoComplete="email"
          inputMode="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="you@icloud.com"
          className="h-11 border-border/80 bg-background/70"
          aria-label="Apple ID email"
        />
        <Button
          type="submit"
          disabled={!emailLooksValid || submitting}
          className="h-11 gap-2 px-5"
        >
          {submitting ? "Joining..." : "Join waitlist"}
          <ArrowRight className="h-4 w-4" />
        </Button>
      </div>
      <p className="text-xs text-muted-foreground">
        Use the same email as your Apple ID / iCloud account for invite matching.
      </p>
      {error ? (
        <p className="text-xs text-red-400">{error}</p>
      ) : null}
    </form>
  )
}
