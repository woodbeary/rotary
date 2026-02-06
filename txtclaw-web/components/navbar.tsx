"use client"

import { useState } from "react"
import { Menu, X } from "lucide-react"

export function Navbar() {
  const [open, setOpen] = useState(false)

  return (
    <header className="sticky top-0 z-50 border-b border-border/50 bg-background/90 backdrop-blur-md">
      <nav className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <a href="#" className="font-mono text-lg font-bold tracking-tight text-foreground">
          TXT CLAW
        </a>

        <div className="hidden items-center gap-8 sm:flex">
          <a href="#how" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
            How it works
          </a>
          <a href="#features" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
            Features
          </a>
          <a href="#pricing" className="text-sm text-muted-foreground transition-colors hover:text-foreground">
            Pricing
          </a>
          <a
            href="sms:+15738792529"
            className="rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Text now
          </a>
        </div>

        <button
          type="button"
          onClick={() => setOpen(!open)}
          className="text-muted-foreground sm:hidden"
          aria-label="Toggle menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </nav>

      {open && (
        <div className="flex flex-col gap-4 border-t border-border/50 px-6 py-4 sm:hidden">
          <a href="#how" onClick={() => setOpen(false)} className="text-sm text-muted-foreground">
            How it works
          </a>
          <a href="#features" onClick={() => setOpen(false)} className="text-sm text-muted-foreground">
            Features
          </a>
          <a href="#pricing" onClick={() => setOpen(false)} className="text-sm text-muted-foreground">
            Pricing
          </a>
          <a
            href="sms:+15738792529"
            className="rounded-md bg-primary px-4 py-2 text-center text-sm font-medium text-primary-foreground"
          >
            Text now
          </a>
        </div>
      )}
    </header>
  )
}
