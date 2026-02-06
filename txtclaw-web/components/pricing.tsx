"use client"

import { Check, ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const tiers = [
  {
    name: "Pro",
    price: "$19",
    period: "/mo",
    description: "A capable personal AI agent over SMS.",
    features: [
      "Dedicated US phone number",
      "Persistent memory",
      "Web browsing & code execution",
      "Custom system prompts",
      "Standard model access",
    ],
    highlighted: true,
    badge: "Most popular",
  },
  {
    name: "Max",
    price: "$49",
    period: "/mo",
    description: "For power users who want everything.",
    features: [
      "Everything in Pro",
      "Priority response times",
      "Advanced browser automation",
      "Higher usage limits",
      "Early access to new tools",
    ],
    highlighted: false,
    badge: null,
  },
  {
    name: "BYOK",
    price: "$12",
    period: "/mo",
    description: "Bring your own API keys. Pay for what you use.",
    features: [
      "Everything in Pro",
      "Your own OpenAI / Anthropic keys",
      "No markup on model costs",
      "Full model selection",
      "Same agent infrastructure",
    ],
    highlighted: false,
    badge: "Best value",
  },
]

export function Pricing() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section id="pricing" ref={ref} className="relative px-6 py-24 md:py-32">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />

      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-14 max-w-lg opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Pricing
          </p>
          <h2 className="mb-4 text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Simple, honest pricing.
          </h2>
          <p className="text-muted-foreground">
            Try it free. Then negotiate your intro price with the AI.
            Seriously&nbsp;&mdash; the floor is $12/mo.
          </p>
        </div>

        <div className="grid gap-6 lg:grid-cols-3">
          {tiers.map((tier, i) => (
            <Card
              key={tier.name}
              className={cn(
                "relative flex flex-col opacity-0 transition-all duration-300 hover:shadow-lg hover:shadow-foreground/[0.02]",
                tier.highlighted && "border-foreground/20 shadow-lg shadow-foreground/[0.03]",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${i * 100 + 100}ms` }}
            >
              {tier.badge && (
                <Badge
                  className="absolute -top-2.5 left-5 font-mono text-[10px]"
                  variant={tier.highlighted ? "default" : "secondary"}
                >
                  {tier.badge}
                </Badge>
              )}

              <CardHeader className="pb-4">
                <CardTitle className="font-mono text-lg">{tier.name}</CardTitle>
                <div className="flex items-baseline gap-1">
                  <span className="text-4xl font-bold tracking-tight text-foreground">
                    {tier.price}
                  </span>
                  <span className="text-sm text-muted-foreground">
                    {tier.period}
                  </span>
                </div>
                <CardDescription>{tier.description}</CardDescription>
              </CardHeader>

              <CardContent className="flex-1">
                <ul className="flex flex-col gap-3">
                  {tier.features.map((feature) => (
                    <li
                      key={feature}
                      className="flex items-start gap-2.5 text-sm text-muted-foreground"
                    >
                      <Check className="mt-0.5 h-4 w-4 shrink-0 text-foreground" />
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
              </CardContent>

              <CardFooter>
                <Button
                  className="w-full gap-2"
                  variant={tier.highlighted ? "default" : "outline"}
                  asChild
                >
                  <a href="sms:+15738792529">
                    Get started
                    <ArrowRight className="h-3.5 w-3.5" />
                  </a>
                </Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
