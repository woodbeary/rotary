import React from "react"
import type { Metadata, Viewport } from "next"
import { ClerkProvider } from "@clerk/nextjs"
import { GeistPixelGrid, GeistPixelSquare } from "geist/font/pixel"
import { ThemeProvider } from "@/components/theme-provider"
import { CLERK_ENABLED } from "@/lib/clerk-config"
import "./globals.css"

const geistPixelSquare = GeistPixelSquare
const geistPixelGrid = GeistPixelGrid

export const metadata: Metadata = {
  title: "TXT CLAW — AI agent on a real phone number",
  description:
    "Text a real phone number. Get an AI that texts back. No app, no login. Your own dedicated AI agent over SMS.",
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
        {CLERK_ENABLED ? (
          <ClerkProvider>{app}</ClerkProvider>
        ) : (
          app
        )}
      </body>
    </html>
  )
}
