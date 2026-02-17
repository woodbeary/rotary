"use client"

import { markWaitlistJoinedInBrowser } from "@/lib/waitlist"
import { useEffect } from "react"

export function WaitlistSuccessFlag() {
  useEffect(() => {
    markWaitlistJoinedInBrowser()
    window.dispatchEvent(new Event("txtclaw:waitlist-joined"))
  }, [])

  return null
}
