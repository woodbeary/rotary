import { MessageSquare } from "lucide-react"

export function Navbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/50 bg-background/80 backdrop-blur-md">
      <nav className="mx-auto flex max-w-4xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-2">
          <MessageSquare className="h-5 w-5 text-primary" />
          <span className="font-semibold text-foreground">ClawPhone</span>
        </div>

        <div className="flex items-center gap-6 text-sm text-muted-foreground">
          <a href="#features" className="hidden transition-colors hover:text-foreground sm:block">
            Features
          </a>
          <a href="#pricing" className="hidden transition-colors hover:text-foreground sm:block">
            Pricing
          </a>
          <a
            href="sms:+15738792529"
            className="rounded-md bg-primary px-3 py-1.5 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90"
          >
            Text now
          </a>
        </div>
      </nav>
    </header>
  )
}
