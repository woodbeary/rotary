"use client"

import { ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { SmsDemo } from "@/components/sms-demo"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

export function Hero() {
  const { ref, isVisible } = useAnimateOnScroll(0.1)

  return (
    <section ref={ref} className="relative overflow-hidden px-6 pb-24 pt-20 md:pb-32 md:pt-28">
      {/* Subtle radial gradient background */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute left-1/2 top-0 h-[600px] w-[900px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-foreground/[0.02] blur-3xl" />
      </div>

      <div className="relative mx-auto flex max-w-6xl flex-col items-center gap-16 lg:flex-row lg:items-center lg:gap-20">
        {/* Left: Copy */}
        <div
          className={cn(
            "flex max-w-xl flex-1 flex-col items-center gap-6 text-center opacity-0 lg:items-start lg:text-left",
            isVisible && "animate-fade-up"
          )}
        >
          <Badge variant="secondary" className="gap-1.5 px-3 py-1 font-mono text-xs font-normal">
            <span className="relative flex h-1.5 w-1.5">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-emerald-500" />
            </span>
            Live now
          </Badge>

          <h1 className="text-balance text-4xl font-bold tracking-tight text-foreground sm:text-5xl md:text-6xl">
            An AI that lives
            <br />
            on a real phone&nbsp;number.
          </h1>

          <p className="text-pretty text-lg leading-relaxed text-muted-foreground">
            Text it. It texts back. A persistent AI agent with memory, web
            browsing, code execution, and tools&nbsp;&mdash; all over plain SMS.
            No app. No login.
          </p>

          <div className="flex flex-col items-center gap-4 sm:flex-row">
            <Button size="lg" className="gap-2 font-mono text-sm" asChild>
              <a href="sms:+15738792529">
                Text +1 (573) 879-2529
                <ArrowRight className="h-4 w-4" />
              </a>
            </Button>
            <span className="text-sm text-muted-foreground">
              Free to try &middot; No account needed
            </span>
          </div>
        </div>

        {/* Right: SMS Demo */}
        <div
          className={cn(
            "w-full max-w-sm shrink-0 opacity-0",
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
