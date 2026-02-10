"use client"

import { useEffect } from "react"
import { markWaitlistJoinedInBrowser } from "@/lib/waitlist"

export function WaitlistSuccessFlag() {
  useEffect(() => {
    markWaitlistJoinedInBrowser()
    window.dispatchEvent(new Event("txtclaw:waitlist-joined"))
  }, [])

  return null
}
