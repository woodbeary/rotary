"use client"

import {
  Brain,
  Globe,
  KeyRound,
  Lock,
  Smartphone,
  Watch,
} from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { StreamText } from "@/components/stream-text"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const features = [
  {
    icon: Smartphone,
    title: "Real phone number",
    description:
      "A dedicated US number that's yours. Text it from any phone on the planet.",
  },
  {
    icon: Brain,
    title: "Persistent memory",
    description:
      "Your agent remembers every conversation. Context builds over time.",
  },
  {
    icon: Globe,
    title: "Web + code execution",
    description:
      "Browse the web, run code, automate tasks. An agent that does things.",
  },
  {
    icon: KeyRound,
    title: "Bring your own keys",
    description:
      "Use your OpenAI, Anthropic, or any supported model API keys. Zero markup.",
  },
  {
    icon: Lock,
    title: "Privacy-first",
    description:
      "No unsolicited messages. No data selling. Cancel anytime. Export everything.",
  },
  {
    icon: Watch,
    title: "Apple Watch ready",
    description:
      "Your assistant lives in Messages, so it follows you across iPhone, iPad, Mac, and Apple Watch.",
  },
]

export function Features() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section id="features" ref={ref} className="relative px-6 py-24 md:py-32">
      {/* Subtle section separator gradient */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />

      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-14 max-w-lg opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Capabilities
          </p>
          <h2 className="mb-4 text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Not a chatbot.
            <br />
            An agent that works for you.
          </h2>
          <StreamText
            className="text-muted-foreground"
            text="Everything you need from an AI assistant, delivered over the simplest interface there is."
            active={isVisible}
          />
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature, i) => (
            <div
              key={feature.title}
              className={cn(
                "group flex flex-col gap-4 rounded-xl border border-border bg-card p-6 opacity-0 transition-all duration-300 hover:border-foreground/20 hover:shadow-lg hover:shadow-foreground/[0.02]",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${i * 80 + 100}ms` }}
            >
              <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-secondary transition-colors group-hover:bg-foreground/10">
                <feature.icon className="h-5 w-5 text-foreground" />
              </div>
              <h3 className="text-base font-semibold text-foreground">
                {feature.title}
              </h3>
              {feature.title === "Real phone number" ? (
                <Badge variant="secondary" className="w-fit font-mono text-[10px] uppercase">
                  Coming soon
                </Badge>
              ) : null}
              <p className="text-sm leading-relaxed text-muted-foreground">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
