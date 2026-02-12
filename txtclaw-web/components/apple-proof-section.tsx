"use client"

import Image from "next/image"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

const previewImages = [
  {
    src: "/apple/flight.png",
    alt: "TXT CLAW Apple Messages beta flight flow preview",
    title: "Booking and itinerary preview",
  },
  {
    src: "/apple/purchase_opengraph.png",
    alt: "TXT CLAW Apple Messages beta checkout preview",
    title: "Checkout and payment preview",
  },
]

export function AppleProofSection() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section ref={ref} className="relative px-6 py-20 md:py-24">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />

      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-10 max-w-2xl opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Apple beta preview
          </p>
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            A familiar Messages experience, tuned for checkout.
          </h2>
          <p className="mt-4 text-muted-foreground">
            These previews show the beta direction for frictionless booking,
            payment, and follow-up directly in-thread.
          </p>
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          {previewImages.map((item, index) => (
            <figure
              key={item.src}
              className={cn(
                "overflow-hidden rounded-2xl border border-border/70 bg-card opacity-0",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${index * 80 + 100}ms` }}
            >
              <div className="bg-[#f5f5f7] px-4 pb-2 pt-6 dark:bg-zinc-900/40">
                <Image
                  src={item.src}
                  alt={item.alt}
                  width={1440}
                  height={2944}
                  className="mx-auto h-auto w-full max-w-[360px]"
                  sizes="(max-width: 768px) 100vw, 45vw"
                />
              </div>
              <figcaption className="px-4 py-3 text-sm text-muted-foreground">
                {item.title}
              </figcaption>
            </figure>
          ))}
        </div>

        <p className="mt-5 text-xs text-muted-foreground">
          Beta preview imagery only. TXT CLAW is an independent project and is
          not affiliated with Apple.
        </p>
      </div>
    </section>
  )
}
