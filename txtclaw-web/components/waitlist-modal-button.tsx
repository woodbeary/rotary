"use client"

import { useEffect, useState } from "react"
import type { ComponentProps, MouseEvent } from "react"
import { ArrowRight } from "lucide-react"
import { useClerk } from "@clerk/nextjs"
import { Button } from "@/components/ui/button"
import {
  getWaitlistSuccessRedirectUrl,
  isWaitlistMarkedJoinedInBrowser,
} from "@/lib/waitlist"

type WaitlistModalButtonProps = Omit<
  ComponentProps<typeof Button>,
  "children" | "asChild"
> & {
  label?: string
  signedInLabel?: string
  source?: string
  showIcon?: boolean
}

export function WaitlistModalButton({
  label = "Join Waitlist",
  signedInLabel = "You're on waitlist",
  source = "site",
  showIcon = true,
  onClick,
  ...buttonProps
}: WaitlistModalButtonProps) {
  const clerk = useClerk()
  const clerkEnabled = Boolean(process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY)
  const successRedirectUrl = getWaitlistSuccessRedirectUrl()
  const [alreadyJoined, setAlreadyJoined] = useState(false)

  useEffect(() => {
    if (!clerkEnabled) return

    const syncJoinedState = () => {
      const signedIn = Boolean(clerk.user?.id)
      setAlreadyJoined(signedIn || isWaitlistMarkedJoinedInBrowser())
    }

    syncJoinedState()
    window.addEventListener("storage", syncJoinedState)
    window.addEventListener("txtclaw:waitlist-joined", syncJoinedState)

    return () => {
      window.removeEventListener("storage", syncJoinedState)
      window.removeEventListener("txtclaw:waitlist-joined", syncJoinedState)
    }
  }, [clerk.user?.id, clerkEnabled])

  const openWaitlistFallback = () => {
    const params = new URLSearchParams({ source })
    window.location.assign(`/waitlist?${params.toString()}`)
  }

  const content = (text: string) => (
    <>
      {text}
      {showIcon && <ArrowRight className="h-4 w-4" />}
    </>
  )

  if (!clerkEnabled) {
    return (
      <Button asChild {...buttonProps}>
        <a href="/waitlist">{content(label)}</a>
      </Button>
    )
  }

  if (alreadyJoined) {
    return (
      <Button type="button" disabled {...buttonProps}>
        {content(signedInLabel)}
      </Button>
    )
  }

  const handleClick = (event: MouseEvent<HTMLButtonElement>) => {
    onClick?.(event)
    if (event.defaultPrevented) return

    try {
      void Promise.resolve(
        clerk.openWaitlist({
          afterJoinWaitlistUrl: successRedirectUrl,
        })
      ).catch(() => {
        openWaitlistFallback()
      })
    } catch {
      openWaitlistFallback()
    }
  }

  return (
    <Button
      type="button"
      data-waitlist-source={source}
      {...buttonProps}
      onClick={handleClick}
    >
      {content(label)}
    </Button>
  )
}
