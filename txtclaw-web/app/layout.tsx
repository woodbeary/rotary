import React from "react"
import type { Metadata, Viewport } from "next"
import localFont from "next/font/local"
import { Analytics } from "@vercel/analytics/next"
import { SpeedInsights } from "@vercel/speed-insights/next"
import { ThemeProvider } from "@/components/theme-provider"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import "./globals.css"

const geistPixelSquare = localFont({
  src: "./fonts/GeistPixel-Square.woff2",
  variable: "--font-geist-pixel-square",
  weight: "500",
  adjustFontFallback: false,
  fallback: [
    "Geist Mono",
    "ui-monospace",
    "SFMono-Regular",
    "Roboto Mono",
    "Menlo",
    "Monaco",
    "Liberation Mono",
    "DejaVu Sans Mono",
    "Courier New",
    "monospace",
  ],
})

const geistPixelGrid = localFont({
  src: "./fonts/GeistPixel-Grid.woff2",
  variable: "--font-geist-pixel-grid",
  weight: "500",
  adjustFontFallback: false,
  fallback: [
    "Geist Mono",
    "ui-monospace",
    "SFMono-Regular",
    "Roboto Mono",
    "Menlo",
    "Monaco",
    "Liberation Mono",
    "DejaVu Sans Mono",
    "Courier New",
    "monospace",
  ],
})

function normalizeAppUrl(raw: string | undefined): string {
  const value = String(raw || "").trim().replace(/\/+$/, "")
  const fallback = "https://www.txtclaw.com"
  if (!value) return fallback

  try {
    const url = new URL(value.startsWith("http") ? value : `https://${value}`)
    // Avoid X preview issues when apex redirects are flaky for bots.
    if (url.hostname === "txtclaw.com") {
      url.hostname = "www.txtclaw.com"
    }
    return url.toString().replace(/\/+$/, "")
  } catch {
    return fallback
  }
}

const appUrl = normalizeAppUrl(process.env.NEXT_PUBLIC_APP_URL)

export const metadata: Metadata = {
  metadataBase: new URL(appUrl),
  title: "TXT CLAW — AI agent on a real phone number",
  description:
    "Text a real phone number. Get an AI that texts back. No app, no login. Your own dedicated AI agent over SMS.",
  openGraph: {
    title: "TXT CLAW — AI agent on a real phone number",
    description:
      "Text a real phone number. Get an AI that texts back. No app, no login. Your own dedicated AI agent over SMS.",
    type: "website",
    url: appUrl,
    siteName: "TXT CLAW",
    images: [
      {
        url: "/opengraph.png",
        width: 1200,
        height: 630,
        alt: "TXT CLAW",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "TXT CLAW — AI agent on a real phone number",
    description:
      "Text a real phone number. Get an AI that texts back. No app, no login. Your own dedicated AI agent over SMS.",
    images: ["/opengraph.png"],
  },
  icons: {
    icon: "/favicon.ico",
    shortcut: "/favicon.ico",
    apple: "/icon.png",
  },
}

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#080808" },
  ],
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  const ClerkProviderPromise = CLERK_ENABLED
    ? import("@clerk/nextjs").then((mod) => mod.ClerkProvider)
    : Promise.resolve(null)

  const app = (
    <ThemeProvider
      attribute="class"
      defaultTheme="system"
      enableSystem
      enableColorScheme
      storageKey="txtclaw-theme"
      disableTransitionOnChange
    >
      {children}
      <Analytics />
      <SpeedInsights />
    </ThemeProvider>
  )

  return (
    <html lang="en" className="scroll-smooth" suppressHydrationWarning>
      <body
        className={`${geistPixelSquare.variable} ${geistPixelGrid.variable} font-sans antialiased`}
      >
        {/* Avoid importing Clerk when keys are not configured (local builds). */}
        {CLERK_ENABLED ? (
          <React.Suspense fallback={app}>
            <ClerkProviderGate provider={ClerkProviderPromise}>
              {app}
            </ClerkProviderGate>
          </React.Suspense>
        ) : (
          app
        )}
      </body>
    </html>
  )
}

async function ClerkProviderGate({
  provider,
  children,
}: {
  provider: Promise<
    | (React.ComponentType<React.PropsWithChildren<Record<string, never>>>)
    | null
  >
  children: React.ReactNode
}) {
  const ClerkProvider = await provider
  return ClerkProvider ? <ClerkProvider>{children}</ClerkProvider> : <>{children}</>
}
