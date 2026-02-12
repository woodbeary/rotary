"use client"

import { useEffect, useState } from "react"
import type { ComponentProps, MouseEvent } from "react"
import { ArrowRight } from "lucide-react"
import { useClerk } from "@clerk/nextjs"
import { Button } from "@/components/ui/button"
import { CLERK_ENABLED } from "@/lib/clerk-config"
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

function renderContent(text: string, showIcon: boolean) {
  return (
    <>
      {text}
      {showIcon && <ArrowRight className="h-4 w-4" />}
    </>
  )
}

function ClerkWaitlistModalButton({
  label = "Join Waitlist",
  signedInLabel = "You're on waitlist",
  source = "site",
  showIcon = true,
  onClick,
  ...buttonProps
}: WaitlistModalButtonProps) {
  const clerk = useClerk()
  const successRedirectUrl = getWaitlistSuccessRedirectUrl()
  const [alreadyJoined, setAlreadyJoined] = useState(false)

  useEffect(() => {
    const syncJoinedState = () => {
      setAlreadyJoined(isWaitlistMarkedJoinedInBrowser())
    }

    syncJoinedState()
    window.addEventListener("storage", syncJoinedState)
    window.addEventListener("txtclaw:waitlist-joined", syncJoinedState)

    return () => {
      window.removeEventListener("storage", syncJoinedState)
      window.removeEventListener("txtclaw:waitlist-joined", syncJoinedState)
    }
  }, [clerk.user?.id])

  const openWaitlistFallback = () => {
    const params = new URLSearchParams({ source })
    window.location.assign(`/waitlist?${params.toString()}`)
  }

  if (alreadyJoined) {
    return (
      <Button type="button" disabled {...buttonProps}>
        {renderContent(signedInLabel, showIcon)}
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
      {renderContent(label, showIcon)}
    </Button>
  )
}

export function WaitlistModalButton(props: WaitlistModalButtonProps) {
  const {
    label = "Join Waitlist",
    showIcon = true,
    source = "site",
    ...buttonProps
  } = props
  const params = new URLSearchParams({ source })

  if (!CLERK_ENABLED) {
    return (
      <Button asChild {...buttonProps}>
        <a href={`/waitlist?${params.toString()}`}>
          {renderContent(label, showIcon)}
        </a>
      </Button>
    )
  }

  return <ClerkWaitlistModalButton {...props} />
}
