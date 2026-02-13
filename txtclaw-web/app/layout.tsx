import React from "react"
import type { Metadata, Viewport } from "next"
import { GeistPixelGrid, GeistPixelSquare } from "geist/font/pixel"
import { ThemeProvider } from "@/components/theme-provider"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import "./globals.css"

const geistPixelSquare = GeistPixelSquare
const geistPixelGrid = GeistPixelGrid

const appUrl =
  process.env.NEXT_PUBLIC_APP_URL?.trim().replace(/\/$/, "") ||
  "https://www.txtclaw.com"

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
        url: "/opengraph-image",
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
    images: ["/opengraph-image"],
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
      disableTransitionOnChange
    >
      {children}
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
