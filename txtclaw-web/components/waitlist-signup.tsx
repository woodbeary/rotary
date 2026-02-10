"use client"

import { SignUp } from "@clerk/nextjs"
import { getWaitlistSuccessRedirectUrl } from "@/lib/waitlist"

type WaitlistSignUpProps = {
  source?: string
}

export function WaitlistSignUp({ source = "waitlist_page" }: WaitlistSignUpProps) {
  const successRedirectUrl = getWaitlistSuccessRedirectUrl()

  return (
    <SignUp
      routing="path"
      path="/waitlist"
      forceRedirectUrl={successRedirectUrl}
      fallbackRedirectUrl={successRedirectUrl}
      unsafeMetadata={{ waitlist_source: source }}
      appearance={{
        elements: {
          card: "bg-card border border-border shadow-none",
          headerTitle: "text-foreground",
          headerSubtitle: "text-muted-foreground",
          socialButtonsBlockButton:
            "border border-border bg-background text-foreground hover:bg-accent",
          formButtonPrimary:
            "bg-primary text-primary-foreground hover:bg-primary/90",
          footerActionText: "text-muted-foreground",
          footerActionLink: "text-foreground",
        },
      }}
    />
  )
}
