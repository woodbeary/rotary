"use client"

import type { ComponentProps } from "react"
import { ArrowRight } from "lucide-react"
import { SignUpButton, SignedIn, SignedOut } from "@clerk/nextjs"
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
  ...buttonProps
}: WaitlistModalButtonProps) {
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

  return (
    <>
      <SignedOut>
        <SignUpButton
          mode="modal"
          forceRedirectUrl={successRedirectUrl}
          fallbackRedirectUrl={successRedirectUrl}
          unsafeMetadata={{ waitlist_source: source }}
        >
          <Button {...buttonProps}>{content(label)}</Button>
        </SignUpButton>
      </SignedOut>

      <SignedIn>
        <Button asChild {...buttonProps}>
          <a href="/waitlist/success">{content(signedInLabel)}</a>
        </Button>
      </SignedIn>
    </>
  )
}
