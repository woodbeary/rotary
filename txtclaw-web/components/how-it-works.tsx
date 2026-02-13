"use client"

import {
  MessageSquare,
  MailCheck,
  CreditCard,
  ShieldCheck,
  Sparkles,
} from "lucide-react"
import { StreamText } from "@/components/stream-text"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const steps = [
  {
    icon: MessageSquare,
    title: "Join waitlist",
    description:
      "Join the Apple beta waitlist with your Apple ID email.",
  },
  {
    icon: MailCheck,
    title: "Get invited",
    description:
      "Invites are sent in daily batches as capacity opens.",
  },
  {
    icon: CreditCard,
    title: "Redeem code or continue to payment",
    description:
      "Use your activation code if you have one, otherwise continue with fixed-price checkout on web.",
  },
  {
    icon: ShieldCheck,
    title: "Receive Apple invite",
    description:
      "After payment, you'll receive your Apple invite instructions.",
  },
  {
    icon: Sparkles,
    title: "Start chatting",
    description:
      "First inbound message auto-activates your runtime and replies in-thread.",
  },
]

export function HowItWorks() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section id="how" ref={ref} className="px-6 py-24 md:py-32">
      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-14 max-w-2xl opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Invite-only onboarding
          </p>
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Onboarding that stays out of your way.
          </h2>
          <StreamText
            className="mt-4 text-muted-foreground"
            text="Get an AI that remembers you, browses the web for you, and handles tasks all from your normal texting app."
            active={isVisible}
          />
        </div>

        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-5">
          {steps.map((step, i) => (
            <div
              key={step.title}
              className={cn(
                "group relative flex flex-col gap-4 rounded-xl border border-border bg-card p-6 opacity-0 transition-colors hover:border-foreground/20",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${i * 90 + 100}ms` }}
            >
              <div className="flex items-center justify-between">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-secondary transition-colors group-hover:bg-foreground/10">
                  <step.icon className="h-5 w-5 text-foreground" />
                </div>
                <span className="inline-flex h-7 min-w-7 items-center justify-center rounded-full border border-border/70 px-2 font-mono text-[11px] text-muted-foreground">
                  {i + 1}
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
