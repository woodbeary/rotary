"use client"

import Image from "next/image"
import { KeyRound } from "lucide-react"
import { useAnimateOnScroll } from "@/hooks/use-animate-on-scroll"
import { cn } from "@/lib/utils"

type Mockup = {
  src: string
  alt: string
  width: number
  height: number
  hiddenDescription?: string
}

type AppleFeature = {
  eyebrow: string
  title: string
  description: string
  bullets: string[]
  badge?: "passkey"
  mark?: {
    src: string
    alt: string
    width: number
    height: number
  }
  primary: Mockup
  secondary: Mockup
}

const features: AppleFeature[] = [
  {
    eyebrow: "Apple Pay",
    title: "Frictionless checkout in thread.",
    description:
      "Customers can review and confirm purchases directly in Messages with a native Apple Pay flow.",
    bullets: [
      "One touch or glance to complete checkout.",
      "Payment, contact, and order context stay in the same conversation.",
    ],
    mark: {
      src: "/apple/apple-pay-mark.svg",
      alt: "Apple Pay mark",
      width: 166,
      height: 106,
    },
    primary: {
      src: "/apple/Apple.png",
      alt: "Apple Pay checkout iPhone mockup",
      width: 458,
      height: 926,
      hiddenDescription: "Apple Pay confirmation preview",
    },
    secondary: {
      src: "/apple/purchase_opengraph.png",
      alt: "Messages commerce checkout iPhone mockup",
      width: 1440,
      height: 2944,
      hiddenDescription: "Checkout and payment preview",
    },
  },
  {
    eyebrow: "Built-in Authentication",
    title: "Sign in without app friction.",
    description:
      "Customers can verify identity in familiar iPhone patterns without downloading another app.",
    bullets: [
      "Native, recognizable sign-in moments improve trust.",
      "Fewer steps means less drop-off during onboarding.",
    ],
    badge: "passkey",
    primary: {
      src: "/apple/AT&T.png",
      alt: "AT&T sign-in iPhone mockup",
      width: 2586,
      height: 5336,
      hiddenDescription: "Sign-in prompt preview",
    },
    secondary: {
      src: "/apple/T-Mobile.png",
      alt: "T-Mobile sign-in iPhone mockup",
      width: 738,
      height: 1491,
      hiddenDescription: "Verify account preview",
    },
  },
  {
    eyebrow: "Customer Continuity",
    title: "From purchase to follow-up, still in Messages.",
    description:
      "Users can move from checkout to confirmation and support without leaving their message thread.",
    bullets: [
      "Perfect for bookings, reminders, and post-checkout updates.",
      "Apple beta invite instructions are delivered through Apple's official flow.",
    ],
    primary: {
      src: "/apple/purchase_complete_apple.png",
      alt: "Purchase complete with Sign up with Apple iPhone mockup",
      width: 536,
      height: 1162,
      hiddenDescription: "Purchase complete preview",
    },
    secondary: {
      src: "/apple/flight.png",
      alt: "Travel and itinerary iPhone mockup",
      width: 1440,
      height: 2944,
      hiddenDescription: "Booking and itinerary preview",
    },
  },
]

function phonePair(primary: Mockup, secondary: Mockup) {
  return (
    <div className="grid grid-cols-2 items-end gap-3 sm:gap-4">
      {[primary, secondary].map((mock, idx) => (
        <figure
          key={`${mock.src}-${idx}`}
          className="rounded-2xl border border-border/60 bg-card/80 p-2 shadow-sm sm:p-3"
        >
          <div className="flex h-[220px] items-end justify-center sm:h-[260px] lg:h-[240px] xl:h-[260px]">
            <Image
              src={mock.src}
              alt={mock.alt}
              width={mock.width}
              height={mock.height}
              className="h-full w-auto"
              sizes="(max-width: 640px) 42vw, (max-width: 1024px) 34vw, 18vw"
            />
          </div>
          {mock.hiddenDescription ? (
            <figcaption className="sr-only">
              {mock.hiddenDescription}
            </figcaption>
          ) : null}
        </figure>
      ))}
    </div>
  )
}

export function AppleProofSection() {
  const { ref, isVisible } = useAnimateOnScroll()

  return (
    <section ref={ref} className="relative overflow-hidden px-6 py-20 md:py-24">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-border to-transparent" />
      <div className="pointer-events-none absolute -top-24 left-1/2 h-72 w-[56rem] -translate-x-1/2 rounded-full bg-foreground/[0.04] blur-3xl" />

      <div className="mx-auto max-w-6xl">
        <div
          className={cn(
            "mb-10 max-w-3xl opacity-0",
            isVisible && "animate-fade-up"
          )}
        >
          <p className="mb-3 font-mono text-sm text-muted-foreground">
            Apple beta preview
          </p>
          <h2 className="text-balance text-3xl font-bold tracking-tight text-foreground md:text-4xl">
            Premium iPhone-native flows that make signing up feel effortless.
          </h2>
          <p className="mt-4 text-muted-foreground">
            We designed onboarding, checkout, and follow-up to feel familiar to
            everyday iPhone users while keeping the experience fast and simple.
          </p>
        </div>

        <div className="grid gap-5 lg:grid-cols-3">
          {features.map((feature, index) => (
            <article
              key={feature.title}
              className={cn(
                "relative overflow-hidden rounded-2xl border border-border/70 bg-card p-5 opacity-0 sm:p-7",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${index * 80 + 100}ms` }}
            >
              <div className="flex flex-col gap-4">
                <div className="flex items-start justify-between gap-4">
                  <p className="font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground">
                    {feature.eyebrow}
                  </p>
                  {feature.badge === "passkey" ? (
                    <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-[11px] text-muted-foreground">
                      <KeyRound className="h-3.5 w-3.5" />
                      Passkey-ready
                    </div>
                  ) : null}
                </div>

                {feature.mark ? (
                  <Image
                    src={feature.mark.src}
                    alt={feature.mark.alt}
                    width={feature.mark.width}
                    height={feature.mark.height}
                    className="h-6 w-auto"
                  />
                ) : null}

                <div>
                  <h3 className="text-balance text-2xl font-semibold tracking-tight text-foreground">
                    {feature.title}
                  </h3>
                  <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
                    {feature.description}
                  </p>
                  <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
                    {feature.bullets.map((item) => (
                      <li key={item}>• {item}</li>
                    ))}
                  </ul>
                </div>

                <div className="mt-2 rounded-2xl border border-border/60 bg-gradient-to-b from-[#f5f5f7] to-[#ececf0] p-3 dark:from-zinc-900/60 dark:to-zinc-900/20 sm:p-4">
                  {phonePair(feature.primary, feature.secondary)}
                </div>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
