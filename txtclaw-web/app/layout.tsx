import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/sonner"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import { ClerkProvider } from "@clerk/nextjs"
import { Analytics } from "@vercel/analytics/next"
import { SpeedInsights } from "@vercel/speed-insights/next"
import type { Metadata, Viewport } from "next"
import localFont from "next/font/local"
import React from "react"
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
  const value = String(raw || "")
    .trim()
    .replace(/\/+$/, "")
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
const smsGatewayLive = process.env.NEXT_PUBLIC_SMS_GATEWAY_LIVE === "true"
const siteTitle = smsGatewayLive
  ? "TXT CLAW — AI agent on a real phone number"
  : "TXT CLAW — Apple beta waitlist"
const siteDescription = smsGatewayLive
  ? "Text a real phone number. Get an AI that texts back. No app, no login. Your own dedicated AI agent over SMS."
  : "Join the TXT CLAW Apple beta waitlist for invite-only access while SMS onboarding is temporarily paused."

export const metadata: Metadata = {
  metadataBase: new URL(appUrl),
  title: siteTitle,
  description: siteDescription,
  openGraph: {
    title: siteTitle,
    description: siteDescription,
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
    title: siteTitle,
    description: siteDescription,
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
      <Toaster />
      <Analytics />
      <SpeedInsights />
    </ThemeProvider>
  )

  return (
    <html lang="en" className="scroll-smooth" suppressHydrationWarning>
      <body
        className={`${geistPixelSquare.variable} ${geistPixelGrid.variable} font-sans antialiased`}
      >
        {CLERK_ENABLED ? <ClerkProvider>{app}</ClerkProvider> : app}
      </body>
    </html>
  )
}
