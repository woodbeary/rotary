export function Footer() {
  return (
    <footer className="border-t border-border px-6 py-8">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-6 md:flex-row md:justify-between">
        <div className="flex items-center gap-6 text-sm text-muted-foreground">
          <span className="font-mono font-semibold text-foreground">TXT CLAW</span>
          <span className="hidden h-4 w-px bg-border md:block" />
          <span>
            Built with{" "}
            <a
              href="https://openclaw.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground underline underline-offset-4 transition-colors hover:text-primary"
            >
              OpenClaw
            </a>
            {" & "}
            <a
              href="https://cloudflare.com"
              target="_blank"
              rel="noopener noreferrer"
              className="text-foreground underline underline-offset-4 transition-colors hover:text-primary"
            >
              Cloudflare
            </a>
          </span>
        </div>

        <div className="flex items-center gap-6 text-sm text-muted-foreground">
          <a
            href="#"
            className="transition-colors hover:text-foreground"
          >
            Privacy
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
