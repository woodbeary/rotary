import { Separator } from "@/components/ui/separator"

export function Footer() {
  return (
    <footer className="px-6 pb-8 pt-4">
      <Separator className="mb-8" />
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-6 md:flex-row md:justify-between">
        <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm text-muted-foreground">
          <span className="font-mono text-xs font-semibold text-foreground">
            TXT CLAW
          </span>
          <span className="hidden h-3.5 w-px bg-border md:block" />
          <span>
            Built with{" "}
            <a
              href="https://openclaw.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground underline underline-offset-4 transition-colors hover:text-muted-foreground"
            >
              OpenClaw
            </a>
            {" & "}
            <a
              href="https://cloudflare.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground underline underline-offset-4 transition-colors hover:text-muted-foreground"
            >
              Cloudflare
            </a>
          </span>
        </div>

        <div className="flex items-center gap-5 text-sm text-muted-foreground">
          <a
            href="/privacy"
            className="transition-colors hover:text-foreground"
          >
            Privacy
          </a>
          <a
            href="/terms"
            className="transition-colors hover:text-foreground"
          >
            Terms
          </a>
          <a
            href="https://x.com/jacoblopez"
            target="_blank"
            rel="noopener noreferrer"
            className="transition-colors hover:text-foreground"
          >
            @jacoblopez
          </a>
        </div>
      </div>
    </footer>
  )
}
