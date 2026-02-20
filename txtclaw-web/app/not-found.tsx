"use client"

import Link from "next/link"
import { useEffect, useMemo, useState } from "react"

const BAYER_4 = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
] as const

const DITHER_GLYPHS = " .:-=+*#%@"

const SLOGANS = [
  "Launch an AI phone lane in minutes.",
  "A real number, branded replies, no app installs.",
  "Stay human at scale with traceable AI texting.",
  "High-trust messaging flows built for operators.",
] as const

const SOCIAL_LINES = [
  "Teams choose TXT CLAW for speed-to-launch and clear API ergonomics.",
  "Operators use it to cut response lag while keeping message quality high.",
  "Founders use it when they need a premium SMS experience without heavy setup.",
  "Product teams use it to test and ship new messaging journeys quickly.",
] as const

const TRUST_SIGNALS = [
  "API-first",
  "Dedicated Agent Memory",
  "Trace IDs on Responses",
  "Launch-Ready UX",
] as const

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

function buildDitherFrame(columns: number, rows: number, tick: number): string {
  const centerX = columns * 0.58 + Math.sin(tick * 0.04) * 5
  const centerY = rows * 0.5 + Math.cos(tick * 0.05) * 2
  const maxDistance = Math.hypot(columns, rows)
  const lines: string[] = []

  for (let y = 0; y < rows; y += 1) {
    let line = ""
    for (let x = 0; x < columns; x += 1) {
      const waveA = Math.sin((x + tick * 1.5) * 0.12)
      const waveB = Math.cos((y - tick * 0.9) * 0.2)
      const distance = Math.hypot(x - centerX, y - centerY) / maxDistance
      const glow = clamp(1 - distance * 2.1, 0, 1)
      const threshold = (BAYER_4[y % 4][x % 4] + 0.5) / 16

      const base = (waveA + waveB + 2) / 4
      const density = clamp(base * 0.5 + glow * 0.9 - threshold * 0.36, 0, 1)
      const index = Math.min(DITHER_GLYPHS.length - 1, Math.floor(density * DITHER_GLYPHS.length))
      line += DITHER_GLYPHS[index]
    }
    lines.push(line)
  }

  return lines.join("\n")
}

export default function NotFound() {
  const [tick, setTick] = useState(0)
  const [reduceMotion, setReduceMotion] = useState(false)
  const [messageIndex, setMessageIndex] = useState(0)
  const [columns, setColumns] = useState(96)
  const [rows, setRows] = useState(30)

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)")
    const handleMedia = () => setReduceMotion(media.matches)
    handleMedia()
    media.addEventListener("change", handleMedia)
    return () => media.removeEventListener("change", handleMedia)
  }, [])

  useEffect(() => {
    const onResize = () => {
      setColumns(clamp(Math.floor(window.innerWidth / 8), 64, 150))
      setRows(clamp(Math.floor(window.innerHeight / 16), 20, 46))
    }
    onResize()
    window.addEventListener("resize", onResize)
    return () => window.removeEventListener("resize", onResize)
  }, [])

  useEffect(() => {
    if (reduceMotion) return
    const timer = window.setInterval(() => setTick((value) => value + 1), 120)
    return () => window.clearInterval(timer)
  }, [reduceMotion])

  useEffect(() => {
    if (reduceMotion) return
    const rotator = window.setInterval(() => {
      setMessageIndex((value) => (value + 1) % SLOGANS.length)
    }, 3300)
    return () => window.clearInterval(rotator)
  }, [reduceMotion])

  const frame = useMemo(() => buildDitherFrame(columns, rows, tick), [columns, rows, tick])
  const slogan = SLOGANS[messageIndex]
  const socialLine = SOCIAL_LINES[messageIndex % SOCIAL_LINES.length]

  return (
    <main className="relative min-h-screen overflow-hidden bg-zinc-950 text-zinc-100">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_18%_16%,rgba(249,115,22,0.26),transparent_50%),radial-gradient(circle_at_78%_82%,rgba(59,130,246,0.22),transparent_48%)]" />
      <div className="pointer-events-none absolute inset-0 opacity-35">
        <pre
          aria-hidden
          className="h-full w-full overflow-hidden px-2 py-4 text-[9px] leading-[1.06] text-zinc-400/70 sm:text-[10px] font-[family-name:var(--font-geist-pixel-grid)]"
        >
          {frame}
        </pre>
      </div>

      <div className="relative z-10 mx-auto flex min-h-screen w-full max-w-6xl flex-col items-center justify-center gap-7 px-4 py-8 sm:px-6">
        <div className="w-full max-w-3xl rounded-2xl border border-zinc-700/70 bg-zinc-950/65 p-6 text-center backdrop-blur-md sm:p-8">
          <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-orange-300/85">
            Route Not Found
          </p>
          <h1 className="mt-2 text-balance font-mono text-3xl font-semibold tracking-tight text-zinc-50 md:text-5xl">
            404: this page slipped between pixels
          </h1>
          <p className="mt-3 text-balance text-sm text-zinc-300 md:text-base">
            That route is missing, but the signal is strong.
          </p>

          <div className="mt-6 rounded-xl border border-zinc-700/70 bg-black/40 px-4 py-4">
            <p className="text-[11px] uppercase tracking-[0.2em] text-zinc-400">Brand Signal</p>
            <p
              key={`s-${messageIndex}`}
              className="mt-2 text-balance font-mono text-xl text-zinc-50 animate-fade-up md:text-2xl"
            >
              {slogan}
            </p>
            <p
              key={`t-${messageIndex}`}
              className="mt-3 text-balance text-sm text-zinc-300 animate-fade-in"
            >
              {socialLine}
            </p>
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-center gap-2">
            {TRUST_SIGNALS.map((signal) => (
              <span
                key={signal}
                className="rounded-full border border-zinc-700 bg-zinc-900/70 px-3 py-1 font-mono text-[11px] text-zinc-200"
              >
                {signal}
              </span>
            ))}
          </div>

          <div className="mt-6 flex flex-wrap items-center justify-center gap-3">
            <Link
              href="/"
              className="rounded-md border border-zinc-500 bg-zinc-100 px-4 py-2 font-mono text-xs text-zinc-950 transition hover:bg-white"
            >
              Go Home
            </Link>
            <Link
              href="/developers"
              className="rounded-md border border-zinc-600 bg-zinc-900/70 px-4 py-2 font-mono text-xs text-zinc-100 transition hover:bg-zinc-800"
            >
              Open Developers
            </Link>
          </div>
        </div>
      </div>
    </main>
  )
}
