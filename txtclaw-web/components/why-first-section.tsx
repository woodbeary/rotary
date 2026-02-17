"use client"

import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { SMS_GATEWAY_LIVE } from "@/lib/launch"
import { cn } from "@/lib/utils"
import { ShieldCheck } from "lucide-react"

export function WhyFirstSection() {
  const { ref, isVisible } = useAnimateOnScroll()

  if (SMS_GATEWAY_LIVE) return null

  return (
    <section ref={ref} className="px-6 pb-20 md:pb-24">
      <div
        className={cn(
          "mx-auto max-w-4xl rounded-2xl border border-border bg-card p-7 opacity-0 md:p-8",
          isVisible && "animate-fade-up",
        )}
      >
        <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-xs font-medium text-foreground/90">
          <ShieldCheck className="h-3.5 w-3.5" />
          Why Apple first
        </div>

        <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
          We start on Apple to keep onboarding simple while we harden reliability and support before
          broader rollout.
        </p>

        <details className="mt-4 rounded-xl border border-border/70 bg-muted/20 p-4 text-sm">
          <summary className="cursor-pointer font-medium text-foreground">
            Security &amp; privacy details
          </summary>
          <div className="mt-3 space-y-2 text-muted-foreground">
            <p>
              Each approved account is routed through its own dedicated conversation channel in the
              TXT CLAW runtime.
            </p>
            <p>
              Messages run over Apple&apos;s messaging infrastructure and follow Apple account-level
              protections.
            </p>
            <p>Works anywhere Messages works, including Wi-Fi-only Apple devices.</p>
          </div>
        </details>
      </div>
    </section>
  )
}
