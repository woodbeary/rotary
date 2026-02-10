"use client"

import type { ComponentProps, MouseEvent } from "react"
import { ArrowRight } from "lucide-react"
import { useClerk } from "@clerk/nextjs"
import { Button } from "@/components/ui/button"
import { getWaitlistSuccessRedirectUrl } from "@/lib/waitlist"

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

  // Retained for compatibility with existing callsites.
  void signedInLabel

  const handleClick = (event: MouseEvent<HTMLButtonElement>) => {
    onClick?.(event)
    if (event.defaultPrevented) return

    clerk.openWaitlist({
      afterJoinWaitlistUrl: successRedirectUrl,
    })
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
