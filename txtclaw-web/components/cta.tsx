"use client"

import { ArrowRight, ShieldCheck } from "lucide-react"
import { Button } from "@/components/ui/button"
import { WaitlistModalButton } from "@/components/waitlist-modal-button"
import { StreamText } from "@/components/stream-text"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { SMS_GATEWAY_LIVE, SMS_PHONE_DISPLAY, SMS_PHONE_HREF } from "@/lib/launch"
import { cn } from "@/lib/utils"

export function CTA() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section ref={ref} className="px-6 py-24 md:py-32">
      <div className="mx-auto grid max-w-4xl gap-4">
        {!SMS_GATEWAY_LIVE ? (
          <article
            className={cn(
              "rounded-2xl border border-border bg-card p-7 opacity-0 md:p-8",
              isVisible && "animate-fade-up"
            )}
          >
            <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-xs font-medium text-foreground/90">
              <ShieldCheck className="h-3.5 w-3.5" />
              Why Apple first
            </div>
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
              We start on Apple to keep onboarding simple while we harden
              reliability and support before broader rollout.
            </p>
            <details className="mt-4 rounded-xl border border-border/70 bg-muted/20 p-4 text-sm">
              <summary className="cursor-pointer font-medium text-foreground">
                Security &amp; privacy details
              </summary>
              <div className="mt-3 space-y-2 text-muted-foreground">
                <p>
                  Each approved account is routed through its own dedicated
                  conversation channel in the TXT CLAW runtime.
                </p>
                <p>
                  Messages run over Apple&apos;s messaging infrastructure and follow
                  Apple account-level protections.
                </p>
                <p>
                  Works anywhere Messages works, including Wi-Fi-only Apple
                  devices.
                </p>
              </div>
            </details>
          </article>
        ) : null}

        <article
          className={cn(
            "relative overflow-hidden rounded-2xl border border-border bg-card opacity-0",
            isVisible && "animate-scale-in"
          )}
        >
          <div className="pointer-events-none absolute inset-0 bg-gradient-to-br from-foreground/[0.02] to-transparent" />

          <div className="relative flex flex-col items-center gap-5 p-8 text-center md:p-12">
            {!SMS_GATEWAY_LIVE ? (
              <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-xs font-medium text-foreground/90">
                Apple beta
              </div>
            ) : null}
            <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
              {SMS_GATEWAY_LIVE ? "Ready? Just text it." : "Apple beta is open"}
            </h2>
            <StreamText
              className="max-w-md text-muted-foreground"
              text={
                SMS_GATEWAY_LIVE
                  ? "No sign-up form. No app store. Message it and meet your AI."
                  : "Join the invite-only Apple beta waitlist. Use your Apple ID email."
              }
              active={isVisible}
            />

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
                variant="default"
                className="gap-2 font-mono text-sm"
                source="cta_section"
              />
            )}
          </div>
        </article>
      </div>
    </section>
  )
}
