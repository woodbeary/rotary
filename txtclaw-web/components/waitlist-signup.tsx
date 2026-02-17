"use client"

import { getWaitlistSuccessRedirectUrl } from "@/lib/waitlist"
import { Waitlist } from "@clerk/nextjs"

export function WaitlistSignUp() {
  const successRedirectUrl = getWaitlistSuccessRedirectUrl()

  return (
    <div className="space-y-3">
      <p className="text-xs text-muted-foreground">
        Important: use the same email as your Apple ID / iCloud account for invite profile matching.
      </p>
      <Waitlist
        afterJoinWaitlistUrl={successRedirectUrl}
        appearance={{
          elements: {
            card: "bg-card border border-border shadow-none",
            headerTitle: "text-foreground",
            headerSubtitle: "text-muted-foreground",
            socialButtonsBlockButton:
              "border border-border bg-background text-foreground hover:bg-accent",
            formButtonPrimary: "bg-primary text-primary-foreground hover:bg-primary/90",
            footerActionText: "text-muted-foreground",
            footerActionLink: "text-foreground",
          },
        }}
      />
    </div>
  )
}
