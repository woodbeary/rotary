"use client"

import { SmsDemo } from "@/components/sms-demo"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"

export function SmsDemoSection() {
  // Only start the chat once it's meaningfully in view on mobile.
  const { ref, isVisible } = useAnimateOnScroll<HTMLDivElement>(0.6)

  return (
    <section className="px-6 pb-24 pt-6 sm:pt-10 lg:hidden">
      <div className="mx-auto max-w-sm">
        <div ref={ref}>
          {isVisible ? (
            <div className="animate-fade-up">
              <SmsDemo />
            </div>
          ) : (
            // Keep initial splash clean; the demo mounts once you scroll to it.
            <div className="h-28 sm:h-36" />
          )}
        </div>
      </div>
    </section>
  )
}
