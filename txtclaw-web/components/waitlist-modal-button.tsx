"use client"

import { useEffect, useState } from "react"
import type { ComponentProps, MouseEvent } from "react"
import { ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { isWaitlistMarkedJoinedInBrowser } from "@/lib/waitlist"

const WAITLIST_FORM_ID = "waitlist-form"

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

function scrollToWaitlistForm() {
  const target = document.getElementById(WAITLIST_FORM_ID)
  if (!target) return false

  target.scrollIntoView({ behavior: "smooth", block: "start" })
  window.history.replaceState({}, "", `/#${WAITLIST_FORM_ID}`)
  return true
}

export function WaitlistModalButton({
  label = "Join Waitlist",
  signedInLabel = "You're on waitlist",
  source = "site",
  showIcon = true,
  onClick,
  ...buttonProps
}: WaitlistModalButtonProps) {
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
  }, [])

  if (alreadyJoined) {
    return (
      <Button type="button" disabled {...buttonProps}>
        {renderContent(signedInLabel, showIcon)}
      </Button>
    )
  }

  const handleClick = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event as unknown as MouseEvent<HTMLButtonElement>)
    if (event.defaultPrevented) return

    const isHomepage = window.location.pathname === "/"
    if (!isHomepage) return

    event.preventDefault()
    if (scrollToWaitlistForm()) return

    const params = new URLSearchParams({ source })
    window.location.assign(`/waitlist?${params.toString()}`)
  }

  return (
    <Button asChild {...buttonProps}>
      <a
        href={`/#${WAITLIST_FORM_ID}`}
        data-waitlist-source={source}
        onClick={handleClick}
      >
        {renderContent(label, showIcon)}
      </a>
    </Button>
  )
}
