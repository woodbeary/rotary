"use client"

import { useEffect, useMemo, useState } from "react"
import { ArrowRight, Check } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { StreamText } from "@/components/stream-text"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { WaitlistModalButton } from "@/components/waitlist-modal-button"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

type LaunchStatsPayload = {
  ok?: boolean
  earlyBirdClaimed?: number
  earlyBirdCap?: number
  ltdClaimed?: number
  ltdCap?: number
  waitlistCount?: number
  recentPaid?: Array<{ initial?: string; timestamp?: string }>
}

const DEFAULT_STATS = {
  earlyBirdClaimed: 0,
  earlyBirdCap: 100,
  ltdClaimed: 0,
  ltdCap: 10,
  waitlistCount: 0,
  recentPaid: [] as Array<{ initial: string; timestamp: string }>,
}

export function Pricing() {
  const { ref, isVisible } = useAnimateOnScroll()
  const [stats, setStats] = useState(DEFAULT_STATS)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false

    const load = async () => {
      setLoading(true)
      try {
        const response = await fetch("/api/launch/stats", {
          method: "GET",
          cache: "no-store",
        })
        const payload = (await response.json().catch(() => null)) as
          | LaunchStatsPayload
          | null

        if (cancelled || !response.ok || !payload?.ok) {
          return
        }

        setStats({
          earlyBirdClaimed:
            typeof payload.earlyBirdClaimed === "number"
              ? payload.earlyBirdClaimed
              : DEFAULT_STATS.earlyBirdClaimed,
          earlyBirdCap:
            typeof payload.earlyBirdCap === "number"
              ? payload.earlyBirdCap
              : DEFAULT_STATS.earlyBirdCap,
          ltdClaimed:
            typeof payload.ltdClaimed === "number"
              ? payload.ltdClaimed
              : DEFAULT_STATS.ltdClaimed,
          ltdCap:
            typeof payload.ltdCap === "number"
              ? payload.ltdCap
              : DEFAULT_STATS.ltdCap,
          waitlistCount:
            typeof payload.waitlistCount === "number"
              ? payload.waitlistCount
              : DEFAULT_STATS.waitlistCount,
          recentPaid: Array.isArray(payload.recentPaid)
            ? payload.recentPaid
                .map((entry) => ({
                  initial:
                    typeof entry?.initial === "string"
                      ? entry.initial.slice(0, 1).toUpperCase()
                      : "U",
                  timestamp:
                    typeof entry?.timestamp === "string"
                      ? entry.timestamp
                      : new Date().toISOString(),
                }))
                .filter((entry) => Boolean(entry.initial && entry.timestamp))
            : [],
        })
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void load()

    return () => {
      cancelled = true
    }
  }, [])

  const earlyBirdRemaining = Math.max(stats.earlyBirdCap - stats.earlyBirdClaimed, 0)
  const ltdRemaining = Math.max(stats.ltdCap - stats.ltdClaimed, 0)

  const monthly = useMemo(() => {
    if (earlyBirdRemaining > 0) {
      return {
        price: "$16",
        period: "/mo",
        badge: "Early bird",
        subtitle: `${earlyBirdRemaining} of ${stats.earlyBirdCap} early bird seats remaining.`,
      }
    }

    return {
      price: "$19",
      period: "/mo",
      badge: "Standard",
      subtitle: "Early bird sold out. Standard launch pricing is active.",
    }
  }, [earlyBirdRemaining, stats.earlyBirdCap])

  return (
    <section id="pricing" ref={ref} className="relative px-6 py-24 md:py-32">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />

      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-14 max-w-2xl opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">Pricing</p>
          <h2 className="mb-4 text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Fixed launch pricing.
          </h2>
          <StreamText
            className="text-muted-foreground"
            text="Website checkout only. No negotiation. Fixed launch pricing for early access."
            active={isVisible}
          />
        </div>

        <div className="grid gap-6 lg:grid-cols-2">
          <Card
            className={cn(
              "relative flex flex-col opacity-0 transition-all duration-300 hover:shadow-lg hover:shadow-foreground/[0.02]",
              isVisible && "animate-fade-up"
            )}
            style={{ animationDelay: "100ms" }}
          >
            <Badge className="absolute -top-2.5 left-5 font-mono text-[10px]" variant="default">
              {monthly.badge}
            </Badge>

            <CardHeader className="pb-4">
              <CardTitle className="font-mono text-lg">Launch monthly</CardTitle>
              <div className="flex items-baseline gap-1">
                <span className="text-4xl font-bold tracking-tight text-foreground">
                  {monthly.price}
                </span>
                <span className="text-sm text-muted-foreground">{monthly.period}</span>
              </div>
              <CardDescription>
                First 100 paid seats are $16/mo, then $19/mo.
              </CardDescription>
            </CardHeader>

            <CardContent className="flex-1 space-y-3">
              <ul className="flex flex-col gap-3">
                {[
                  "Apple beta chat access",
                  "Runtime auto-activation on first inbound",
                  "Persistent memory and tool use",
                  "Apple invite after payment",
                ].map((feature) => (
                  <li
                    key={feature}
                    className="flex items-start gap-2.5 text-sm text-muted-foreground"
                  >
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-foreground" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>
              <p className="text-xs text-muted-foreground">{monthly.subtitle}</p>
            </CardContent>

            <CardFooter className="flex flex-col items-start gap-3">
              <div className="flex w-full gap-2">
                <WaitlistModalButton
                  className="w-full gap-2"
                  source="pricing_monthly"
                  showIcon={false}
                />
                <Button variant="outline" className="w-full gap-2" asChild>
                  <a href="/subscribe">
                    I have an invite
                    <ArrowRight className="h-3.5 w-3.5" />
                  </a>
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Claimed: {stats.earlyBirdClaimed}/{stats.earlyBirdCap}
                {" · "}
                Waitlist: {stats.waitlistCount}
              </p>
            </CardFooter>
          </Card>

          <Card
            className={cn(
              "relative flex flex-col opacity-0 transition-all duration-300 hover:shadow-lg hover:shadow-foreground/[0.02]",
              isVisible && "animate-fade-up"
            )}
            style={{ animationDelay: "180ms" }}
          >
            <Badge className="absolute -top-2.5 left-5 font-mono text-[10px]" variant="secondary">
              Limited drop
            </Badge>

            <CardHeader className="pb-4">
              <CardTitle className="font-mono text-lg">BYOK lifetime</CardTitle>
              <div className="flex items-baseline gap-1">
                <span className="text-4xl font-bold tracking-tight text-foreground">
                  $299
                </span>
                <span className="text-sm text-muted-foreground">one-time</span>
              </div>
              <CardDescription>
                10 seats total. First-come, first-served.
              </CardDescription>
            </CardHeader>

            <CardContent className="flex-1 space-y-3">
              <ul className="flex flex-col gap-3">
                {[
                  "Bring your own model keys",
                  "No recurring TXT CLAW subscription",
                  "Access to Apple beta chat runtime",
                  "Apple invite after payment",
                ].map((feature) => (
                  <li
                    key={feature}
                    className="flex items-start gap-2.5 text-sm text-muted-foreground"
                  >
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-foreground" />
                    <span>{feature}</span>
                  </li>
                ))}
              </ul>
              <p className="text-xs text-muted-foreground">
                {ltdRemaining > 0
                  ? `${ltdRemaining} seats remaining.`
                  : "Sold out."}
              </p>
            </CardContent>

            <CardFooter className="flex flex-col items-start gap-3">
              <div className="flex w-full gap-2">
                <WaitlistModalButton
                  className="w-full gap-2"
                  source="pricing_ltd"
                  showIcon={false}
                />
                <Button
                  variant="outline"
                  className="w-full gap-2"
                  asChild
                  disabled={ltdRemaining <= 0}
                >
                  <a href="/subscribe">Claim on invite</a>
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Claimed: {stats.ltdClaimed}/{stats.ltdCap}
                {" · "}
                Waitlist: {stats.waitlistCount}
              </p>
            </CardFooter>
          </Card>
        </div>

        {loading ? (
          <p className="mt-6 text-xs text-muted-foreground">
            Loading live counters…
          </p>
        ) : null}
        {stats.recentPaid.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2">
            {stats.recentPaid.slice(0, 10).map((entry, index) => {
              const dateLabel = new Date(entry.timestamp).toLocaleDateString(
                "en-US",
                { month: "short", day: "numeric" }
              )

              return (
                <span
                  key={`${entry.initial}-${entry.timestamp}-${index}`}
                  className="rounded-full border border-border/70 px-2.5 py-1 font-mono text-[11px] text-muted-foreground"
                >
                  {entry.initial} • {dateLabel}
                </span>
              )
            })}
          </div>
        ) : null}
      </div>
    </section>
  )
}
