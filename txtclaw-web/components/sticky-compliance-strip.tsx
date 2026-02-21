"use client"

import { SMS_PHONE_DISPLAY, SMS_PHONE_HREF } from "@/lib/launch"

export function StickyComplianceStrip() {
  return (
    <div className="fixed inset-x-0 bottom-0 z-50 border-t border-zinc-700 bg-zinc-950/95 text-zinc-100 backdrop-blur">
      <div className="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-2 text-[11px] sm:flex-row sm:items-center sm:justify-between sm:gap-4">
        <p className="font-semibold">
          Text us:{" "}
          <a
            href={SMS_PHONE_HREF}
            className="font-mono underline underline-offset-4 transition-opacity hover:opacity-80"
          >
            {SMS_PHONE_DISPLAY}
          </a>
        </p>
        <p className="text-zinc-300">
          Message and data rates may apply. Reply STOP to opt out. Reply HELP for help.
        </p>
        <p className="flex items-center gap-2">
          <a
            href="/privacy"
            className="underline underline-offset-4 transition-opacity hover:opacity-80"
          >
            Privacy Policy
          </a>
          <span className="text-zinc-500">|</span>
          <a
            href="/terms"
            className="underline underline-offset-4 transition-opacity hover:opacity-80"
          >
            Terms and Conditions
          </a>
        </p>
      </div>
    </div>
  )
}
