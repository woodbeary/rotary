"use client"

import { Waitlist } from "@clerk/nextjs"
import { getWaitlistSuccessRedirectUrl } from "@/lib/waitlist"

export function WaitlistSignUp() {
  const successRedirectUrl = getWaitlistSuccessRedirectUrl()

  return (
    <Waitlist
      afterJoinWaitlistUrl={successRedirectUrl}
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
