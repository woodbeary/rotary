"use client"

import { ArrowRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { WaitlistModalButton } from "@/components/waitlist-modal-button"
import { SMS_GATEWAY_LIVE, SMS_PHONE_DISPLAY, SMS_PHONE_HREF } from "@/lib/launch"
import { cn } from "@/lib/utils"

export function CTA() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section ref={ref} className="px-6 py-24 md:py-32">
      <div
        className={cn(
          "relative mx-auto max-w-4xl overflow-hidden rounded-2xl border border-border bg-card opacity-0",
          isVisible && "animate-scale-in"
        )}
      >
        {/* Subtle gradient overlay */}
        <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-foreground/[0.02] to-transparent" />

        <div className="relative flex flex-col items-center gap-6 p-10 text-center md:p-16">
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            {SMS_GATEWAY_LIVE ? "Ready? Just text it." : "Launching soon"}
          </h2>
          <p className="max-w-md text-muted-foreground">
            {SMS_GATEWAY_LIVE
              ? "No sign-up form. No app store. Send a text and meet your AI."
              : "Join the waitlist and get first access when TXT CLAW goes live."}
          </p>
          {SMS_GATEWAY_LIVE ? (
            <Button size="lg" className="gap-2 font-mono text-sm" asChild>
              <a href={SMS_PHONE_HREF}>
                {`Text ${SMS_PHONE_DISPLAY}`}
                <ArrowRight className="h-4 w-4" />
              </a>
            </Button>
          ) : (
            <WaitlistModalButton
              size="lg"
              className="gap-2 font-mono text-sm"
              source="cta_section"
            />
          )}
        </div>
      </div>
    </section>
  )
}
