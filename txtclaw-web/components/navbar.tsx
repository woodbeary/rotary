"use client"

import { useState } from "react"
import Image from "next/image"
import { Menu } from "lucide-react"
import { Button } from "@/components/ui/button"
import { ThemeToggle } from "@/components/theme-toggle"
import { SMS_GATEWAY_LIVE, SMS_PHONE_HREF } from "@/lib/launch"
import {
  Sheet,
  SheetContent,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"

const links = [
  { href: "#how", label: "How it works" },
  { href: "#features", label: "Features" },
  { href: "#pricing", label: "Pricing" },
]

export function Navbar() {
  const [open, setOpen] = useState(false)

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/80 backdrop-blur-xl">
      <nav className="mx-auto flex h-20 max-w-6xl items-center justify-between px-6">
        <a
          href="/"
          className="flex items-center gap-2"
          aria-label="TXT CLAW home"
        >
          <Image
            src="/logo_horizontal_lightmode.webp"
            alt="TXT CLAW"
            width={1200}
            height={295}
            className="h-14 w-auto dark:hidden"
          />
          <Image
            src="/logo_horizontal_darkmode.webp"
            alt="TXT CLAW"
            width={1200}
            height={295}
            className="hidden h-14 w-auto dark:block"
          />
        </a>

        {/* Desktop */}
        <div className="hidden items-center gap-1 md:flex">
          {links.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="rounded-md px-3 py-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              {link.label}
            </a>
          ))}
          <a
            href="/api-reference"
            className="ml-1 inline-flex items-center rounded-full border border-border/70 bg-background/70 px-3 py-1 font-mono text-[11px] text-muted-foreground transition-colors hover:border-foreground/25 hover:text-foreground"
          >
            View API Docs
          </a>
          <div className="mx-2 h-4 w-px bg-border" />
          <ThemeToggle />
          {SMS_GATEWAY_LIVE && (
            <Button size="sm" className="ml-1" asChild>
              <a href={SMS_PHONE_HREF}>Text now</a>
            </Button>
          )}
        </div>

        {/* Mobile */}
        <div className="flex items-center gap-1 md:hidden">
          <ThemeToggle />
          <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="h-9 w-9" aria-label="Open menu">
                <Menu className="h-5 w-5" />
              </Button>
            </SheetTrigger>
            <SheetContent side="right" className="w-72">
              <SheetTitle className="font-mono text-base tracking-tighter">
                TXT CLAW
              </SheetTitle>
              <div className="mt-8 flex flex-col gap-1">
                {links.map((link) => (
                  <a
                    key={link.href}
                    href={link.href}
                    onClick={() => setOpen(false)}
                    className="rounded-md px-3 py-2.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                  >
                    {link.label}
                  </a>
                ))}
                <a
                  href="/api-reference"
                  onClick={() => setOpen(false)}
                  className="mt-1 inline-flex items-center rounded-full border border-border/70 bg-background/70 px-3 py-1 font-mono text-[11px] text-muted-foreground transition-colors hover:border-foreground/25 hover:text-foreground"
                >
                  View API Docs
                </a>
                <div className="my-3 h-px bg-border" />
                {SMS_GATEWAY_LIVE && (
                  <Button className="w-full" asChild>
                    <a href={SMS_PHONE_HREF} onClick={() => setOpen(false)}>
                      Text now
                    </a>
                  </Button>
                )}
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </nav>
    </header>
  )
}
