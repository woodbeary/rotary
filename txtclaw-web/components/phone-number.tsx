"use client"

import { MessageSquare } from "lucide-react"

export function PhoneNumber() {
  return (
    <a
      href="sms:+15738792529"
      className="group flex items-center gap-3 rounded-lg border border-primary/30 bg-primary/5 px-6 py-4 transition-colors hover:border-primary/60 hover:bg-primary/10"
    >
      <MessageSquare className="h-5 w-5 text-primary" />
      <span className="font-mono text-2xl font-bold tracking-wider text-primary md:text-3xl">
        +1 (573) 879-2529
      </span>
    </a>
  )
}
