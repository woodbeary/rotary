"use client"

import { useEffect, useState } from "react"

const messages = [
  { from: "user", text: "hey, what can you do?" },
  {
    from: "agent",
    text: "I'm your TXT CLAW agent. I can browse the web, run code, remember our past convos, and handle tasks for you. All over text. What do you need?",
  },
  { from: "user", text: "look up flights from STL to LAX next friday" },
  {
    from: "agent",
    text: "Found 3 options. Cheapest is Southwest at $147 nonstop, departs 6:15am. Want me to save these or keep looking?",
  },
]

export function SmsDemo() {
  const [visibleCount, setVisibleCount] = useState(0)

  useEffect(() => {
    if (visibleCount < messages.length) {
      const timeout = setTimeout(
        () => setVisibleCount((c) => c + 1),
        visibleCount === 0 ? 800 : 1200
      )
      return () => clearTimeout(timeout)
    }
  }, [visibleCount])

  return (
    <div className="mx-auto w-full max-w-sm">
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        {/* Phone header */}
        <div className="flex items-center gap-3 border-b border-border px-4 py-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/20">
            <span className="font-mono text-xs font-bold text-primary">TC</span>
          </div>
          <div>
            <p className="text-sm font-medium text-foreground">TXT CLAW</p>
            <p className="font-mono text-xs text-muted-foreground">+1 (573) 879-2529</p>
          </div>
        </div>

        {/* Messages */}
        <div className="flex flex-col gap-3 p-4" style={{ minHeight: 260 }}>
          {messages.slice(0, visibleCount).map((msg, i) => (
            <div
              key={i}
              className={`flex ${msg.from === "user" ? "justify-end" : "justify-start"}`}
            >
              <div
                className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm leading-relaxed ${
                  msg.from === "user"
                    ? "rounded-br-md bg-primary text-primary-foreground"
                    : "rounded-bl-md bg-secondary text-secondary-foreground"
                }`}
                style={{
                  animation: "fadeSlideIn 0.3s ease-out",
                }}
              >
                {msg.text}
              </div>
            </div>
          ))}

          {visibleCount < messages.length && (
            <div className="flex justify-start">
              <div className="flex gap-1 rounded-2xl rounded-bl-md bg-secondary px-4 py-3">
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-muted-foreground" />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-muted-foreground" style={{ animationDelay: "0.2s" }} />
                <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-muted-foreground" style={{ animationDelay: "0.4s" }} />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
