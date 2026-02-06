"use client"

import { ArrowRight, MessageCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { SmsDemo } from "@/components/sms-demo"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

export function Hero() {
  const { ref, isVisible } = useAnimateOnScroll(0.05)

  return (
    <section ref={ref} className="relative overflow-hidden px-5 pb-20 pt-16 sm:px-6 md:pb-32 md:pt-28">
      {/* Subtle radial glow */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute left-1/2 top-0 h-[600px] w-[900px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-foreground/[0.03] blur-3xl" />
      </div>

      <div className="relative mx-auto flex max-w-6xl flex-col items-center gap-12 lg:flex-row lg:items-center lg:gap-16">
        {/* Left: Copy */}
        <div
          className={cn(
            "flex max-w-2xl flex-1 flex-col items-center gap-5 text-center opacity-0 lg:items-start lg:text-left",
            isVisible && "animate-fade-up"
          )}
        >
          <Badge variant="secondary" className="gap-2 px-3.5 py-1.5 text-sm font-normal">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
            </span>
            Live &mdash; try it right now
          </Badge>

          <h1 className="text-balance text-[2.5rem] font-bold leading-[1.1] tracking-tight text-foreground sm:text-5xl md:text-6xl lg:text-7xl">
            Your own AI.
            <br />
            <span className="text-muted-foreground">One text away.</span>
          </h1>

          <p className="max-w-lg text-pretty text-lg leading-relaxed text-muted-foreground sm:text-xl">
            Send a text. Get an AI that remembers you, browses the web for you,
            and handles tasks&nbsp;&mdash; all from your normal texting&nbsp;app.
            No download. No&nbsp;account. No&nbsp;learning&nbsp;curve.
          </p>

          <div className="flex w-full flex-col items-center gap-3 sm:w-auto sm:flex-row sm:gap-4">
            <Button size="lg" className="w-full gap-2.5 text-base sm:w-auto" asChild>
              <a href="sms:+15738792529">
                <MessageCircle className="h-5 w-5" />
                Text +1 (573) 879-2529
              </a>
            </Button>
            <p className="text-sm text-muted-foreground">
              Free to try &middot; Takes 5 seconds
            </p>
          </div>

          <p className="mt-1 font-mono text-xs text-muted-foreground/70">
            Msg &amp; data rates may apply. Reply STOP to opt out.
          </p>
        </div>

        {/* Right: SMS Demo */}
        <div
          className={cn(
            "w-full max-w-sm shrink-0 opacity-0 lg:max-w-md",
            isVisible && "animate-slide-in-right"
          )}
          style={{ animationDelay: "200ms" }}
        >
          <SmsDemo />
        </div>
      </div>
    </section>
  )
}
