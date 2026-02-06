"use client"

import {
  MessageSquare,
  Handshake,
  Smartphone,
  Settings,
} from "lucide-react"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const steps = [
  {
    icon: MessageSquare,
    number: "01",
    title: "Text the number",
    description:
      "Send anything to +1 (573) 879-2529. The free gateway agent responds in seconds. No signup required.",
  },
  {
    icon: Handshake,
    number: "02",
    title: "Try it, negotiate a price",
    description:
      "Chat for free. Like it? Negotiate your first month with the AI. It starts at $19/mo but you can talk it down.",
  },
  {
    icon: Smartphone,
    number: "03",
    title: "Get your own number",
    description:
      "Pay and instantly receive a dedicated US phone number routed to your own private, persistent agent.",
  },
  {
    icon: Settings,
    number: "04",
    title: "Make it yours",
    description:
      "Custom system prompts, BYOK model access, persistent memory. Your agent learns and grows with you.",
  },
]

export function HowItWorks() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section id="how" ref={ref} className="px-6 py-24 md:py-32">
      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-14 max-w-lg opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            How it works
          </p>
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Four texts to your own AI.
          </h2>
        </div>

        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, i) => (
            <div
              key={step.number}
              className={cn(
                "group relative flex flex-col gap-4 rounded-xl border border-border bg-card p-6 opacity-0 transition-colors hover:border-foreground/20",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${i * 100 + 100}ms` }}
            >
              <div className="flex items-center justify-between">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-secondary transition-colors group-hover:bg-foreground/10">
                  <step.icon className="h-5 w-5 text-foreground" />
                </div>
                <span className="font-mono text-xs text-muted-foreground">
                  {step.number}
                </span>
              </div>
              <h3 className="text-base font-semibold text-foreground">
                {step.title}
              </h3>
              <p className="text-sm leading-relaxed text-muted-foreground">
                {step.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
