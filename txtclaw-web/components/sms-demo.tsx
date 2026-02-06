"use client"

import { useEffect, useState } from "react"
import { cn } from "@/lib/utils"

const messages = [
  { from: "user" as const, text: "hey, what can you do?" },
  {
    from: "agent" as const,
    text: "I can browse the web, run code, remember our past convos, and handle tasks. All over text. What do you need?",
  },
  { from: "user" as const, text: "look up flights from STL to LAX next friday" },
  {
    from: "agent" as const,
    text: "Found 3 options. Cheapest is Southwest at $147 nonstop, departs 6:15am. Want me to save these?",
  },
]

export function SmsDemo() {
  const [visibleCount, setVisibleCount] = useState(0)

  useEffect(() => {
    if (visibleCount < messages.length) {
      const timeout = setTimeout(
        () => setVisibleCount((c) => c + 1),
        visibleCount === 0 ? 600 : 1400
      )
      return () => clearTimeout(timeout)
    }
  }, [visibleCount])

  return (
    <div className="relative mx-auto w-full max-w-sm">
      {/* Glow effect behind the card */}
      <div className="absolute -inset-4 rounded-3xl bg-gradient-to-b from-foreground/[0.03] to-transparent blur-2xl" />

      <div className="relative overflow-hidden rounded-2xl border border-border bg-card shadow-xl shadow-black/5 dark:shadow-black/20">
        {/* Header */}
        <div className="flex items-center gap-3 border-b border-border px-5 py-3.5">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-foreground">
            <span className="font-mono text-xs font-bold text-background">
              TC
            </span>
          </div>
          <div>
            <p className="text-sm font-semibold text-foreground">TXT CLAW</p>
            <p className="font-mono text-xs text-muted-foreground">
              +1 (573) 879-2529
            </p>
          </div>
          <div className="ml-auto flex items-center gap-1.5">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            <span className="text-xs text-muted-foreground">Online</span>
          </div>
        </div>

        {/* Messages */}
        <div className="flex flex-col gap-3 p-4" style={{ minHeight: 280 }}>
          {messages.slice(0, visibleCount).map((msg, i) => (
            <div
              key={i}
              className={cn(
                "flex",
                msg.from === "user" ? "justify-end" : "justify-start"
              )}
              style={{
                animation: "fade-up 0.4s ease-out both",
                animationDelay: "0ms",
              }}
            >
              <div
                className={cn(
                  "max-w-[80%] rounded-2xl px-4 py-2.5 text-[13px] leading-relaxed",
                  msg.from === "user"
                    ? "rounded-br-sm bg-foreground text-background"
                    : "rounded-bl-sm border border-border bg-card text-card-foreground"
                )}
              >
                {msg.text}
              </div>
            </div>
          ))}

          {visibleCount < messages.length && (
            <div className="flex justify-start">
              <div className="flex gap-1.5 rounded-2xl rounded-bl-sm border border-border bg-card px-4 py-3">
                <span className="h-1.5 w-1.5 rounded-full bg-muted-foreground animate-pulse-soft" />
                <span
                  className="h-1.5 w-1.5 rounded-full bg-muted-foreground animate-pulse-soft"
                  style={{ animationDelay: "0.2s" }}
                />
                <span
                  className="h-1.5 w-1.5 rounded-full bg-muted-foreground animate-pulse-soft"
                  style={{ animationDelay: "0.4s" }}
                />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
