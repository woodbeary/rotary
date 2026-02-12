"use client"

import Image from "next/image"
import type { CSSProperties } from "react"
import {
  siAnthropic,
  siCloudflare,
  siGoogle,
  siGooglegemini,
  siGooglejules,
  siNvidia,
} from "simple-icons"
import { cn } from "@/lib/utils"

type BrandIcon = {
  id: string
  href: string
  label: string
  imageSrc?: string
  path?: string
  hex?: string
}

const icons: BrandIcon[] = [
  {
    id: "openai",
    href: "https://openai.com/",
    label: "OpenAI",
    imageSrc: "/partner-icons/openai.png",
  },
  {
    id: "chatgpt",
    href: "https://chatgpt.com/",
    label: "ChatGPT",
    imageSrc: "/partner-icons/chatgpt.png",
  },
  {
    id: "anthropic",
    href: "https://www.anthropic.com/",
    label: "Anthropic",
    path: siAnthropic.path,
    hex: siAnthropic.hex,
  },
  {
    id: "gemini",
    href: "https://deepmind.google/technologies/gemini/",
    label: "Google Gemini",
    path: siGooglegemini.path,
    hex: siGooglegemini.hex,
  },
  {
    id: "gemini-cli",
    href: "https://deepmind.google/technologies/gemini/",
    label: "Gemini CLI",
    path: siGooglegemini.path,
    hex: siGooglegemini.hex,
  },
  {
    id: "jules",
    href: "https://labs.google/",
    label: "Google Jules",
    path: siGooglejules.path,
    hex: siGooglejules.hex,
  },
  {
    id: "google",
    href: "https://about.google/",
    label: "Google",
    path: siGoogle.path,
    hex: siGoogle.hex,
  },
  {
    id: "cloudflare",
    href: "https://www.cloudflare.com/",
    label: "Cloudflare",
    path: siCloudflare.path,
    hex: siCloudflare.hex,
  },
  {
    id: "aws-activate",
    href: "https://aws.amazon.com/activate/",
    label: "AWS Activate",
    imageSrc: "/partner-icons/aws.png",
  },
  {
    id: "nvidia",
    href: "https://www.nvidia.com/",
    label: "NVIDIA",
    path: siNvidia.path,
    hex: siNvidia.hex,
  },
]

type MarqueeRowProps = {
  items: BrandIcon[]
  reverse?: boolean
  durationSeconds: number
}

function MarqueeRow({ items, reverse = false, durationSeconds }: MarqueeRowProps) {
  const looped = [...items, ...items]
  const style = {
    ["--marquee-duration" as string]: `${durationSeconds}s`,
  } as CSSProperties

  return (
    <div className="relative flex overflow-hidden py-2">
      <div
        className={cn(
          "flex min-w-max shrink-0 items-center gap-3 sm:gap-4",
          reverse ? "animate-logo-marquee-reverse" : "animate-logo-marquee"
        )}
        style={style}
      >
        {looped.map((item, index) => (
          <a
            key={`${item.id}-${index}`}
            href={item.href}
            target="_blank"
            rel="noopener noreferrer"
            aria-label={item.label}
            className="group flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-white shadow-[0_0_0_1px_hsl(var(--border)/0.55)] transition-transform duration-300 hover:-translate-y-0.5 sm:h-12 sm:w-12"
          >
            {item.imageSrc ? (
              <Image
                src={item.imageSrc}
                alt={item.label}
                width={26}
                height={26}
                className="h-6 w-6 object-contain"
              />
            ) : (
              <svg
                viewBox="0 0 24 24"
                aria-hidden="true"
                className="h-5 w-5"
                style={{ color: item.hex ? `#${item.hex}` : "currentColor" }}
              >
                <path d={item.path} fill="currentColor" />
              </svg>
            )}
          </a>
        ))}
      </div>
    </div>
  )
}

export function TrustBadges() {
  const rowA = icons
  const rowB = [icons[6], icons[0], icons[7], icons[2], icons[8], icons[3], icons[1], icons[9], icons[5], icons[4]]

  return (
    <section className="relative overflow-hidden px-6 py-6 md:py-8">
      <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-16 bg-gradient-to-r from-background to-transparent sm:w-24" />
      <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-16 bg-gradient-to-l from-background to-transparent sm:w-24" />

      <MarqueeRow items={rowA} durationSeconds={34} />
      <MarqueeRow items={rowB} durationSeconds={38} reverse />
    </section>
  )
}
