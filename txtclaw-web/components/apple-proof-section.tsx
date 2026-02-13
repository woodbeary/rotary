"use client"

import Image from "next/image"
import { useState } from "react"
import { KeyRound } from "lucide-react"
import { StreamText } from "@/components/stream-text"
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
      src: "/apple/Apple.webp",
      alt: "Apple Pay checkout iPhone mockup",
      width: 458,
      height: 926,
      hiddenDescription: "Apple Pay confirmation preview",
    },
    secondary: {
      src: "/apple/purchase_opengraph.webp",
      alt: "Messages commerce checkout iPhone mockup",
      width: 900,
      height: 1840,
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
      src: "/apple/AT&T.webp",
      alt: "AT&T sign-in iPhone mockup",
      width: 900,
      height: 1858,
      hiddenDescription: "Sign-in prompt preview",
    },
    secondary: {
      src: "/apple/T-Mobile.webp",
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
      src: "/apple/purchase_complete_apple.webp",
      alt: "Purchase complete with Sign up with Apple iPhone mockup",
      width: 536,
      height: 1162,
      hiddenDescription: "Purchase complete preview",
    },
    secondary: {
      src: "/apple/flight.webp",
      alt: "Travel and itinerary iPhone mockup",
      width: 900,
      height: 1840,
      hiddenDescription: "Booking and itinerary preview",
    },
  },
]

function MockupCard({
  mock,
  priority = false,
}: {
  mock: Mockup
  priority?: boolean
}) {
  const [isLoaded, setIsLoaded] = useState(false)
  const [hasError, setHasError] = useState(false)

  return (
    <figure className="w-full rounded-2xl border border-border/60 bg-card/80 p-2 shadow-sm sm:p-3">
      <div className="relative flex h-[220px] items-end justify-center sm:h-[250px] lg:h-[280px] xl:h-[300px]">
        <div
          className="relative aspect-[9/19] h-full overflow-hidden rounded-[1rem] bg-black/40"
        >
          {!isLoaded && !hasError ? (
            <div className="absolute inset-0 animate-pulse bg-muted/35" />
          ) : null}
          <Image
            src={mock.src}
            alt={mock.alt}
            width={mock.width}
            height={mock.height}
            loading={priority ? "eager" : "lazy"}
            fetchPriority={priority ? "high" : "auto"}
            onLoad={() => setIsLoaded(true)}
            onError={() => setHasError(true)}
            className={cn(
              "h-full w-auto object-contain object-top transition-opacity duration-300",
              isLoaded ? "opacity-100" : "opacity-0"
            )}
            sizes="(max-width: 640px) 44vw, (max-width: 1024px) 34vw, 17vw"
          />
          {hasError ? (
            <span className="absolute inset-0 grid place-items-center px-3 text-center text-xs text-muted-foreground">
              Image failed to load
            </span>
          ) : null}
        </div>
      </div>
      {mock.hiddenDescription ? (
        <span className="sr-only">{mock.hiddenDescription}</span>
      ) : null}
    </figure>
  )
}

function phonePair(primary: Mockup, secondary: Mockup, prioritizeFirst = false) {
  return (
    <div className="grid grid-cols-2 items-stretch gap-3 sm:gap-4">
      <MockupCard mock={primary} priority={prioritizeFirst} />
      <MockupCard mock={secondary} />
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
          <StreamText
            className="mt-4 text-muted-foreground"
            text="We designed onboarding, checkout, and follow-up to feel familiar to everyday iPhone users while keeping the experience fast and simple."
            active={isVisible}
          />
        </div>

        <div className="grid gap-5 lg:hidden">
          {features.map((feature, index) => (
            <article
              key={feature.title}
              className={cn(
                "relative h-full overflow-hidden rounded-2xl border border-border/70 bg-card p-5 opacity-0 sm:p-7",
                isVisible && "animate-fade-up"
              )}
              style={{ animationDelay: `${index * 80 + 100}ms` }}
            >
              <div className="flex h-full flex-col gap-4">
                <div className="flex flex-wrap items-center gap-2.5">
                  <p className="font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground">
                    {feature.eyebrow}
                  </p>
                  {feature.mark ? (
                    <Image
                      src={feature.mark.src}
                      alt={feature.mark.alt}
                      width={feature.mark.width}
                      height={feature.mark.height}
                      className="h-5 w-auto"
                    />
                  ) : null}
                  {feature.badge === "passkey" ? (
                    <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-[11px] text-muted-foreground">
                      <KeyRound className="h-3.5 w-3.5" />
                      Passkey-ready
                    </div>
                  ) : null}
                </div>

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

                <div className="mt-auto rounded-2xl border border-border/60 bg-gradient-to-b from-[#f5f5f7] to-[#ececf0] p-3 dark:from-zinc-900/60 dark:to-zinc-900/20 sm:p-4">
                  {phonePair(feature.primary, feature.secondary, index === 0)}
                </div>
              </div>
            </article>
          ))}
        </div>

        <div className="hidden lg:flex lg:flex-col lg:gap-6">
          {features.map((feature, index) => {
            const reverse = index % 2 === 1
            return (
              <article
                key={`${feature.title}-desktop`}
                className={cn(
                  "relative overflow-hidden rounded-3xl border border-border/70 bg-card p-8 opacity-0 xl:p-10",
                  isVisible && "animate-fade-up"
                )}
                style={{ animationDelay: `${index * 90 + 120}ms` }}
              >
                <div
                  className={cn(
                    "grid items-center gap-10",
                    reverse
                      ? "grid-cols-[minmax(340px,460px)_minmax(0,1fr)]"
                      : "grid-cols-[minmax(0,1fr)_minmax(340px,460px)]"
                  )}
                >
                  <div className={cn(reverse && "order-2")}>
                    <div className="flex flex-wrap items-center gap-3">
                      <p className="font-mono text-xs uppercase tracking-[0.14em] text-muted-foreground">
                        {feature.eyebrow}
                      </p>
                      {feature.mark ? (
                        <Image
                          src={feature.mark.src}
                          alt={feature.mark.alt}
                          width={feature.mark.width}
                          height={feature.mark.height}
                          className="h-5 w-auto"
                        />
                      ) : null}
                      {feature.badge === "passkey" ? (
                        <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-background/70 px-3 py-1 text-[11px] text-muted-foreground">
                          <KeyRound className="h-3.5 w-3.5" />
                          Passkey-ready
                        </div>
                      ) : null}
                    </div>

                    <h3 className="mt-5 text-balance text-5xl font-semibold tracking-tight text-foreground">
                      {feature.title}
                    </h3>
                    <p className="mt-5 max-w-2xl text-lg leading-relaxed text-muted-foreground">
                      {feature.description}
                    </p>
                    <ul className="mt-6 space-y-3 text-lg text-muted-foreground">
                      {feature.bullets.map((item) => (
                        <li key={item}>• {item}</li>
                      ))}
                    </ul>
                  </div>

                  <div className={cn(reverse && "order-1")}>
                    <div className="rounded-2xl border border-border/60 bg-gradient-to-b from-[#f5f5f7] to-[#ececf0] p-4 dark:from-zinc-900/60 dark:to-zinc-900/20">
                      {phonePair(feature.primary, feature.secondary, index === 0)}
                    </div>
                  </div>
                </div>
              </article>
            )
          })}
        </div>
      </div>
    </section>
  )
}
