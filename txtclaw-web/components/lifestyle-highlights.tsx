"use client"

import { BellRing, Languages, MessageSquareText } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { StreamText } from "@/components/stream-text"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const highlights = [
  {
    icon: MessageSquareText,
    title: "No learning curve.",
    description:
      "Some assistants require a new app and a new workflow. TXT CLAW doesn’t. If you can text, you can use it. Even your grandma.",
  },
  {
    icon: Languages,
    title: "Multi‑language, zero friction.",
    description:
      "Ask in your language. Have it translate, summarize, and draft a reply in theirs. Perfect for fast-moving work and family logistics.",
  },
  {
    icon: BellRing,
    title: "Follow-ups that stick.",
    description:
      "Tell your assistant who you invited and what matters. It can keep the thread warm as dates approach and keep you posted.",
    badge: "Coming soon",
  },
]

export function LifestyleHighlights() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section ref={ref} className="relative px-6 py-18 md:py-24">
      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-10 max-w-2xl opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Built for real life
          </p>
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Text is the interface everyone already knows.
          </h2>
          <StreamText
            className="mt-4 text-muted-foreground"
            text="TXT CLAW is designed for people who want an assistant, not another app to learn."
            active={isVisible}
          />
        </div>

        <div className="grid gap-4 md:grid-cols-3">
          {highlights.map((item, index) => (
            <article
              key={item.title}
              className={cn(
                "relative rounded-2xl border border-border bg-card p-6 opacity-0",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${index * 90 + 100}ms` }}
            >
              <div className="flex items-start justify-between gap-4">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-secondary">
                  <item.icon className="h-5 w-5 text-foreground" />
                </div>
                {item.badge ? (
                  <Badge variant="secondary" className="font-mono text-[10px] uppercase">
                    {item.badge}
                  </Badge>
                ) : null}
              </div>
              <h3 className="mt-4 text-lg font-semibold tracking-tight text-foreground">
                {item.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                {item.description}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
