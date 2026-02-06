export function Footer() {
  return (
    <footer className="border-t border-border px-4 py-8">
      <div className="mx-auto flex max-w-4xl flex-col items-center gap-4 text-center text-sm text-muted-foreground md:flex-row md:justify-between md:text-left">
        <p>
          Built with{" "}
          <a
            href="https://openclaw.com"
            target="_blank"
            rel="noopener noreferrer"
            className="text-foreground underline underline-offset-4 transition-colors hover:text-primary"
          >
            OpenClaw
          </a>{" "}
          &{" "}
          <a
            href="https://cloudflare.com"
            target="_blank"
            rel="noopener noreferrer"
            className="text-foreground underline underline-offset-4 transition-colors hover:text-primary"
          >
            Cloudflare
          </a>
        </p>

        <div className="flex items-center gap-4">
          <a
            href="#"
            className="underline underline-offset-4 transition-colors hover:text-foreground"
          >
            Privacy
          </a>
          <span className="text-border">|</span>
          <a
            href="https://x.com/jacoblopez"
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-4 transition-colors hover:text-foreground"
          >
            @jacoblopez
          </a>
        </div>
      </div>
    </footer>
  )
}
